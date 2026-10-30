// Put this file next to main.dart (lib/supabase_service.dart).
// It is the only place that talks to Supabase tables. AppState calls it.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';

/// Client-side UUID v4, so rows can be created locally with a stable id
/// and inserted into Supabase later without the id changing.
String newId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static User? get currentUser => _db.auth.currentUser;
  static bool get hasSession => _db.auth.currentSession != null;
  static String get _uid => currentUser!.id;

  static Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------

  static Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    // If "Confirm email" is on in Supabase, there is no session yet.
    if (res.session == null) {
      throw const AuthException(
        'Account created. Check your email to confirm it, then sign in.',
      );
    }
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => _db.auth.signOut();

  // -------------------------------------------------------------------------
  // Profile (coins + subscription are read-only for the client)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> fetchProfile() async {
    return await _db.from('profiles').select().eq('id', _uid).maybeSingle();
  }

  static Future<void> updateFullName(String name) async {
    await _db.from('profiles').update({'full_name': name}).eq('id', _uid);
  }

  // -------------------------------------------------------------------------
  // Contacts + lists
  // -------------------------------------------------------------------------

  static Future<List<Contact>> fetchContacts() async {
    final out = <Contact>[];
    const page = 1000; // PostgREST returns at most 1000 rows per request
    var from = 0;
    while (true) {
      final rows = await _db
          .from('contacts')
          .select(
            'id, name, phone, email, '
            'contact_list_members(contact_lists(name, is_purchased))',
          )
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .range(from, from + page - 1);

      for (final r in rows) {
        var group = '';
        var isList = false;
        final members = (r['contact_list_members'] as List?) ?? const [];
        if (members.isNotEmpty) {
          final list = (members.first as Map)['contact_lists'] as Map?;
          group = (list?['name'] as String?) ?? '';
          isList = list?['is_purchased'] == true;
        }
        out.add(Contact(
          name: (r['name'] as String?) ?? '',
          phone: (r['phone'] as String?) ?? '',
          email: (r['email'] as String?) ?? '',
          group: group,
          isList: isList,
        ));
      }
      if (rows.length < page) break;
      from += page;
    }
    return out;
  }

  static Future<String> _ensureList(String name, bool isPurchased) async {
    final existing = await _db
        .from('contact_lists')
        .select('id')
        .eq('user_id', _uid)
        .eq('name', name)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await _db
        .from('contact_lists')
        .insert({'user_id': _uid, 'name': name, 'is_purchased': isPurchased})
        .select('id')
        .single();
    return created['id'] as String;
  }

  /// Inserts contacts (already de-duplicated by AppState) and links them to
  /// their group/list.
  static Future<void> saveContacts(List<Contact> contacts) async {
    if (contacts.isEmpty) return;
    final uid = _uid;

    final listIds = <String, String>{};
    for (final c in contacts) {
      if (c.group.isEmpty || listIds.containsKey(c.group)) continue;
      listIds[c.group] = await _ensureList(c.group, c.isList);
    }

    for (var i = 0; i < contacts.length; i += 500) {
      final chunk = contacts.sublist(i, min(i + 500, contacts.length));
      final inserted = await _db
          .from('contacts')
          .insert([
            for (final c in chunk)
              {
                'user_id': uid,
                'name': c.name.isEmpty ? null : c.name,
                'phone': c.phone.isEmpty ? null : c.phone,
                'email': c.email.isEmpty ? null : c.email,
              },
          ])
          .select('id, phone, email');

      final idByKey = <String, String>{
        for (final r in inserted)
          (((r['phone'] as String?) ?? '').isNotEmpty
                  ? r['phone'] as String
                  : (r['email'] as String? ?? '')):
              r['id'] as String,
      };

      final members = <Map<String, dynamic>>[];
      for (final c in chunk) {
        final listId = listIds[c.group];
        final contactId = idByKey[c.key];
        if (listId == null || contactId == null) continue;
        members.add({'user_id': uid, 'list_id': listId, 'contact_id': contactId});
      }
      if (members.isNotEmpty) {
        await _db.from('contact_list_members').insert(members);
      }
    }
  }

  static Future<void> deleteContact(Contact c) async {
    if (c.key.isEmpty) return;

    final column = c.phone.isNotEmpty ? 'phone' : 'email';
    final rows = await _db
        .from('contacts')
        .select('id')
        .eq('user_id', _uid)
        .eq(column, c.key);

    final ids = rows
        .map((row) => row['id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return;

    // Remove list memberships first so deletion also works when the database
    // does not have ON DELETE CASCADE configured for contact_list_members.
    await _db
        .from('contact_list_members')
        .delete()
        .eq('user_id', _uid)
        .inFilter('contact_id', ids);

    await _db
        .from('contacts')
        .delete()
        .eq('user_id', _uid)
        .inFilter('id', ids);
  }

  // -------------------------------------------------------------------------
  // Campaigns
  // -------------------------------------------------------------------------

  static String _campaignStatusOut(CampaignStatus s) => switch (s) {
        CampaignStatus.queued => 'queued',
        CampaignStatus.sending => 'sending',
        CampaignStatus.completed => 'sent',
      };

  static CampaignStatus _campaignStatusIn(String s) => switch (s) {
        'sending' => CampaignStatus.sending,
        'draft' || 'queued' || 'scheduled' => CampaignStatus.queued,
        _ => CampaignStatus.completed, // sent, partially_failed, failed, cancelled
      };

  static Future<void> saveCampaign(Campaign c) async {
    // Upsert makes retrying a campaign safe when the same campaign ID already
    // exists. It does not create a second campaign row.
    await _db.from('campaigns').upsert({
      'id': c.id,
      'user_id': _uid,
      'name': c.name,
      'message': c.message,
      'subject': c.subject.isEmpty ? null : c.subject,
      'sender_name': c.fromName.isEmpty ? null : c.fromName,
      'sender_email': c.fromEmail.isEmpty ? null : c.fromEmail,
      'channel': c.channel == Channel.sms ? 'sms' : 'email',
      'status': _campaignStatusOut(c.status),
      'recipients_count': c.recipients,
    }, onConflict: 'id');
  }

  static Future<void> setCampaignStatus(String id, CampaignStatus s) async {
    await _db
        .from('campaigns')
        .update({'status': _campaignStatusOut(s)})
        .eq('id', id)
        .eq('user_id', _uid);
  }

  static Future<List<Campaign>> fetchCampaigns() async {
    final rows = await _db
        .from('campaigns')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(200);

    return [
      for (final r in rows)
        Campaign(
          id: r['id'] as String,
          name: r['name'] as String,
          message: r['message'] as String,
          subject: (r['subject'] as String?) ?? '',
          fromName: (r['sender_name'] as String?) ?? '',
          fromEmail: (r['sender_email'] as String?) ?? '',
          channel: r['channel'] == 'email' ? Channel.email : Channel.sms,
          recipients: r['recipients_count'] as int,
          sentCount: (r['sent_count'] as int?) ?? (r['delivered_count'] as int? ?? 0),
          delivered: (r['delivered_count'] as int?) ?? 0,
          failed: (r['failed_count'] as int?) ?? 0,
          opened: (r['opened_count'] as int?) ?? 0,
          replies: (r['replied_count'] as int?) ?? 0,
          status: _campaignStatusIn(r['status'] as String),
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  }

  // -------------------------------------------------------------------------
  // Conversations + messages
  // -------------------------------------------------------------------------

  static MessageStatus _msgStatusIn(String s) => switch (s) {
        'read' => MessageStatus.read,
        'delivered' || 'received' => MessageStatus.delivered,
        'failed' => MessageStatus.failed,
        _ => MessageStatus.sent, // queued, sent
      };

  static Future<List<Conversation>> fetchConversations() async {
    final rows = await _db
        .from('conversations')
        .select('*, campaigns(name), messages(*)')
        .eq('user_id', _uid)
        .order('last_message_at', ascending: false)
        .limit(200);

    final out = <Conversation>[];
    for (final r in rows) {
      final raw = ((r['messages'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
        ..sort((a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String));

      out.add(Conversation(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '',
        address: r['address'] as String,
        channel: r['channel'] == 'email' ? Channel.email : Channel.sms,
        campaign: (r['campaigns'] as Map?)?['name'] as String?,
        unread: r['unread'] == true,
        messages: [
          for (final m in raw)
            ChatMessage(
              id: m['id'] as String,
              text: m['text'] as String,
              outbound: m['direction'] == 'outbound',
              time: DateTime.parse(m['created_at'] as String).toLocal(),
              status: _msgStatusIn(m['status'] as String),
              isEdited: m['is_edited'] == true,
            ),
        ],
      ));
    }
    return out;
  }

  /// Creates the conversation row if it does not exist yet (no-op otherwise),
  /// then stores the message. Outbound messages start as 'queued'; a backend
  /// worker (e.g. an Edge Function calling Telnyx) should move them to
  /// sent/delivered/failed.
  static Future<void> saveOutboundMessage(
    Conversation convo,
    ChatMessage msg,
  ) async {
    await _db.from('conversations').upsert(
      {
        'id': convo.id,
        'user_id': _uid,
        'name': convo.name.isEmpty ? null : convo.name,
        'address': convo.address,
        'channel': convo.channel == Channel.sms ? 'sms' : 'email',
      },
      onConflict: 'id',
      ignoreDuplicates: true,
    );

    await _db.from('messages').insert({
      'id': msg.id,
      'conversation_id': convo.id,
      'text': msg.text,
      'direction': 'outbound',
      'status': 'queued',
    });

    await _db
        .from('conversations')
        .update({'last_message_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', convo.id)
        .eq('user_id', _uid);
  }

  /// Updates the saved message status after the provider send attempt.
  static Future<void> updateMessageStatus(String id, String status) async {
    await _db.from('messages').update({
      'status': status,
    }).eq('id', id);
  }

  static Future<void> updateMessageText(String id, String text) async {
    await _db.from('messages').update({
      'text': text,
      'is_edited': true,
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> deleteMessage(String id) async {
    await _db.from('messages').delete().eq('id', id);
  }

  static Future<void> updateConversationContact(
    String id, {
    required String name,
    required String address,
  }) async {
    await _db
        .from('conversations')
        .update({'name': name, 'address': address})
        .eq('id', id)
        .eq('user_id', _uid);
  }

  static Future<void> markConversationRead(String id) async {
    await _db
        .from('conversations')
        .update({'unread': false})
        .eq('id', id)
        .eq('user_id', _uid);
  }

  static Future<void> deleteConversation(String id) async {
    await _db.from('conversations').delete().eq('id', id).eq('user_id', _uid);
  }

  // -------------------------------------------------------------------------
  // Edge Functions / Email Sending
  // -------------------------------------------------------------------------

  static Future<bool> sendEmailCampaign({
    required String campaignId,
    required String campaignName,
    required List<String> recipientEmails,
    required String fromName,
    required String fromEmail,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'send-email',
        body: {
          'action': 'send_campaign',
          'campaign_id': campaignId,
          'name': campaignName,
          'channel': 'email',
          'addresses': recipientEmails,
          'fromName': fromName,
          'fromEmail': fromEmail,
          'subject': subject,
          'message': message,
        },
      );
      final data = response.data;
      return response.status >= 200 && response.status < 300 &&
          data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('Error starting Brevo email campaign: $e');
      return false;
    }
  }
}
