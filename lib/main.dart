import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rgveqbunscitzinexcfh.supabase.co',
    publishableKey: 'sb_publishable_k_Iu9BnOSCFizcNtaTgHWw_oXoHYGNB',
  );

  runApp(const LeadTextApp());
}



/// Launch switch. While false, LeadMarket and LeadCoins are hidden from the
/// app (Contacts takes the tab) and the home screen shows a small "Soon"
/// banner. Flip to true later and everything comes back.
const bool kLeadMarketEnabled = true;

/// Global text scale applied on top of the user's system setting.
const double kTextScale = 0.94;

// ---------------------------------------------------------------------------
// Design tokens (light mode)
// ---------------------------------------------------------------------------

const Color kBg = Color(0xFFF6F8FC);
const Color kSurface = Color(0xFFFFFFFF);
const Color kSurfaceHi = Color(0xFFF0F4FA);
const Color kLine = Color(0xFFE2E8F0);
const Color kAccent = Color(0xFF001EC7);
const Color kAccentBright = Color(0xFF2344E8);
const Color kText = Color(0xFF0F172A);
const Color kMuted = Color(0xFF475569);
const Color kFaint = Color(0xFF64748B);
const Color kGreen = Color(0xFF15803D);
const Color kAmber = Color(0xFFB45309);
const Color kRed = Color(0xFFB91C1C);

const TextStyle h1 = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: kText,
  letterSpacing: -0.7,
  height: 1.18,
);

const TextStyle h2 = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: kText,
  letterSpacing: -0.2,
);

const TextStyle bodyMuted = TextStyle(fontSize: 13, color: kMuted, height: 1.5, letterSpacing: 0.05);

const TextStyle rowTitle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w600,
  color: kText,
);

const TextStyle rowSub = TextStyle(fontSize: 11.5, color: kMuted, height: 1.4, letterSpacing: 0.05);

void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// Lets AppState show messages without a BuildContext.
final GlobalKey<ScaffoldMessengerState> kMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final Random _uuidRnd = Random.secure();

/// Random UUID v4 (the database ids are uuids).
String _uuid() {
  final b = List<int>.generate(16, (_) => _uuidRnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// Turns an Edge Function / network error into a short readable message.
String friendlyError(Object e) {
  try {
    final d = (e as dynamic).details;
    if (d is Map) {
      final m = d['error'] ?? d['message'];
      if (m != null && m.toString().isNotEmpty) return m.toString();
    }
    if (d is String && d.trim().isNotEmpty) return d;
  } catch (_) {}
  return e.toString().replaceFirst('Exception: ', '');
}

String formatCount(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

String formatMoney(double amount) => '\$${amount.toStringAsFixed(2)}';

String formatCoins(int n) => '${formatCount(n)} LC';

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime d) =>
    '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

String formatShortDate(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}';

String timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return formatDate(t);
}

String longTimeAgo(DateTime t) {
  final s = timeAgo(t);
  return s == 'now' ? 'Just now' : '$s ago';
}

/// Assumed price per SMS segment, used only for an estimate. Real charges are
/// billed by Telnyx to the customer's own account.
const double smsPricePerSegment = 0.004;

/// Below this Telnyx balance (in dollars) the app shows a low-balance warning.
const double kLowBalanceThreshold = 5.0;

int smsSegments(String text) {
  if (text.isEmpty) return 0;
  final unicode = text.runes.any((r) => r > 127);
  final single = unicode ? 70 : 160;
  final multi = unicode ? 67 : 153;
  final length = text.runes.length;
  return length <= single ? 1 : (length / multi).ceil();
}

final RegExp _emailRegex = RegExp(r'[\w.+\-]+@[\w\-]+(?:\.[\w\-]+)+');

bool isValidEmail(String s) =>
    RegExp(r'^[\w.+\-]+@[\w\-]+(?:\.[\w\-]+)+$').hasMatch(s.trim());

// ---------------------------------------------------------------------------
// Brand mark (matches the app icon)
// ---------------------------------------------------------------------------

class LogoMark extends StatelessWidget {
  final double size;
  final bool plate;

  const LogoMark({super.key, this.size = 36, this.plate = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(plate: plate)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final bool plate;

  const _LogoPainter({required this.plate});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1024);

    if (plate) {
      final rect = const Rect.fromLTWH(0, 0, 1024, 1024);
      final bg = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2542FF), Color(0xFF001EC7), Color(0xFF0A1240)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(232)),
        bg,
      );
    }

    final bubble = Path()
      ..addRRect(
        RRect.fromLTRBR(232, 262, 792, 692, const Radius.circular(124)),
      );
    final tail = Path()
      ..moveTo(300, 640)
      ..lineTo(292, 806)
      ..lineTo(470, 676)
      ..close();
    final body = Path.combine(PathOperation.union, bubble, tail);

    final bar1 = Path()
      ..addRRect(RRect.fromLTRBR(398, 372, 470, 592, const Radius.circular(16)));
    final bar2 = Path()
      ..addRRect(RRect.fromLTRBR(398, 520, 630, 592, const Radius.circular(16)));
    final dot = Path()
      ..addOval(Rect.fromCircle(center: const Offset(594, 416), radius: 36));
    final glyph = Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, bar1, bar2),
      dot,
    );

    final mark = Path.combine(PathOperation.difference, body, glyph);
    canvas.drawPath(mark, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.plate != plate;
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum Channel { sms, email }

extension ChannelX on Channel {
  String get label => this == Channel.sms ? 'SMS' : 'Email';
  IconData get icon =>
      this == Channel.sms ? Icons.sms_outlined : Icons.mail_outline_rounded;
}

class Contact {
  final String name;
  final String phone;
  final String email;

  /// Name of the group or purchased list this contact belongs to ('' = none).
  final String group;

  /// True when [group] is a purchased lead list rather than a plain group.
  final bool isList;

  const Contact({
    required this.name,
    this.phone = '',
    this.email = '',
    this.group = '',
    this.isList = false,
  });

  String get key => phone.isNotEmpty ? phone : email;

  String get displayName => name.isNotEmpty ? name : detail;

  String get detail => phone.isNotEmpty ? prettyPhone : email;

  String get prettyPhone {
    if (phone.startsWith('+1') && phone.length == 12) {
      return '+1 (${phone.substring(2, 5)}) '
          '${phone.substring(5, 8)}-${phone.substring(8)}';
    }
    return phone;
  }

  String get initials {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

enum MessageStatus { sent, delivered, read, failed }

class ChatMessage {
  final String id;
  String text;
  final bool outbound;
  final DateTime time;
  MessageStatus status;
  bool isEdited;

  ChatMessage({
    String? id,
    required this.text,
    required this.outbound,
    required this.time,
    this.status = MessageStatus.delivered,
    this.isEdited = false,
  }) : id = id ?? 'm_${DateTime.now().microsecondsSinceEpoch}';
}

class Conversation {
  final String id;
  String name;
  String address;
  final Channel channel;
  final String? campaign;
  final List<ChatMessage> messages;
  bool unread;

  Conversation({
    required this.id,
    required this.name,
    required this.address,
    required this.channel,
    required this.messages,
    this.campaign,
    this.unread = false,
  });

  // Safe non-nullable getter with a fallback dummy message if the list is empty
  ChatMessage get last => messages.isNotEmpty
      ? messages.last
      : ChatMessage(
          text: 'No messages yet',
          time: DateTime.now(),
          outbound: true,
          status: MessageStatus.sent,
        );

  String get title => name.isNotEmpty ? name : address;

  String get initials {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

enum CampaignStatus { queued, sending, completed }

class Campaign {
  final String id;
  final bool demoSim; // <--- Add this field here
  final String name;
  final String message;
  final String subject;
  final Channel channel;
  final int recipients;
  final int segments;
  final DateTime createdAt;
  int delivered;
  int failed;
  int opened;
  int replies;
  CampaignStatus status;

  Campaign({
    String? id,
    this.demoSim = false, // <--- Add this parameter here
    required this.name,
    required this.message,
    required this.channel,
    required this.recipients,
    this.subject = '',
    this.segments = 1,
    this.delivered = 0,
    this.failed = 0,
    this.opened = 0,
    this.replies = 0,
    this.status = CampaignStatus.queued,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  int get sent => delivered + failed;
  bool get isActive => status != CampaignStatus.completed;
  double get progress =>
      recipients == 0 ? 0 : (sent / recipients).clamp(0.0, 1.0).toDouble();
}
/// Everything entered on the "New campaign" screen, passed along the flow.
class CampaignDraft {
  final String name;
  final String subject;
  final String fromName;
  final String fromEmail;
  final String message;
  final Channel channel;
  final int segments;

  const CampaignDraft({
    required this.name,
    required this.subject,
    required this.fromName,
    required this.fromEmail,
    required this.message,
    required this.channel,
    required this.segments,
  });
}

class MessageTemplate {
  final String name;
  final String blurb;
  final Channel channel;
  final String subject;
  final String body;
  final IconData icon;

  const MessageTemplate({
    required this.name,
    required this.blurb,
    required this.channel,
    required this.body,
    this.subject = '',
    this.icon = Icons.chat_bubble_outline_rounded,
  });
}

const List<MessageTemplate> kTemplates = [
  MessageTemplate(
    name: 'Website outreach',
    blurb: 'Introduce your services',
    channel: Channel.sms,
    icon: Icons.language_rounded,
    body: 'Hi! We help local businesses get more customers online. '
        'Want a free 10-minute audit of your website? Reply STOP to opt out.',
  ),
  MessageTemplate(
    name: 'Follow up',
    blurb: 'Re-engage prospects',
    channel: Channel.sms,
    icon: Icons.reply_rounded,
    body: 'Hi, just following up on my earlier message. Is this something '
        'you would like to explore this week? Reply STOP to opt out.',
  ),
  MessageTemplate(
    name: 'Special offer',
    blurb: 'Limited-time deal',
    channel: Channel.sms,
    icon: Icons.local_offer_outlined,
    body: 'This week only: 20% off our setup. Reply YES and we will send '
        'the details. Reply STOP to opt out.',
  ),
  MessageTemplate(
    name: 'Appointment reminder',
    blurb: 'Confirm upcoming calls',
    channel: Channel.sms,
    icon: Icons.event_available_outlined,
    body: 'Reminder: we have a call scheduled with you tomorrow. Reply 1 to '
        'confirm or 2 to reschedule. Reply STOP to opt out.',
  ),
  MessageTemplate(
    name: 'Product launch',
    blurb: 'Announce something new',
    channel: Channel.sms,
    icon: Icons.rocket_launch_outlined,
    body: 'We just launched something new and wanted you to hear it first. '
        'Reply INFO for details. Reply STOP to opt out.',
  ),
  MessageTemplate(
    name: 'Introduction',
    blurb: 'First email to a new contact',
    channel: Channel.email,
    icon: Icons.waving_hand_outlined,
    subject: 'Quick idea for your business',
    body: 'Hi,\n\nWe help businesses get more customers with simple websites '
        'and automation. Would a free 10-minute audit be useful?\n\n'
        'Just reply to this email and we will set it up.\n\n'
        'Reply UNSUBSCRIBE to stop receiving these emails.',
  ),
  MessageTemplate(
    name: 'Special offer',
    blurb: 'Limited-time deal',
    channel: Channel.email,
    icon: Icons.local_offer_outlined,
    subject: 'A special offer for your business',
    body: 'Hi,\n\nThis week only, we are offering 20% off our automation '
        'setup. Reply to this email if you would like the details.\n\n'
        'Reply UNSUBSCRIBE to stop receiving these emails.',
  ),
  MessageTemplate(
    name: 'Follow up',
    blurb: 'Nudge a previous email',
    channel: Channel.email,
    icon: Icons.reply_rounded,
    subject: 'Following up',
    body: 'Hi,\n\nJust checking in on my previous email. Happy to answer any '
        'questions or share a few examples.\n\n'
        'Reply UNSUBSCRIBE to stop receiving these emails.',
  ),
];

class ProviderConnection {
  final String maskedKey;
  final String smsNumber;
  final String emailDomain;

  const ProviderConnection({
    required this.maskedKey,
    required this.smsNumber,
    this.emailDomain = '',
  });
}

class LedgerEntry {
  final String title;
  final int amount; // LeadCoins, signed
  final DateTime time;

  const LedgerEntry({
    required this.title,
    required this.amount,
    required this.time,
  });
}

class CoinBundle {
  final int coins;
  final double price;

  const CoinBundle(this.coins, this.price);
}

enum ContactType { phone, email, both }

extension ContactTypeX on ContactType {
  String get label => switch (this) {
        ContactType.phone => 'Phone Number Only',
        ContactType.email => 'Email Only',
        ContactType.both => 'Email + Phone Number',
      };

  String get shortLabel => switch (this) {
        ContactType.phone => 'Phone',
        ContactType.email => 'Email',
        ContactType.both => 'Email + Phone',
      };

  String get blurb => switch (this) {
        ContactType.phone => 'Businesses with a phone number',
        ContactType.email => 'Businesses with an email address',
        ContactType.both => 'Only businesses with both phone and email',
      };

  String get guarantee => switch (this) {
        ContactType.phone => 'Phone number on every lead',
        ContactType.email => 'Email address on every lead',
        ContactType.both => 'Phone + email on every lead',
      };

  /// Launch pricing in dollars per 1,000 leads. 1 LeadCoin = $1.
  int get pricePer1000 => switch (this) {
        ContactType.phone => 15,
        ContactType.email => 20,
        ContactType.both => 30,
      };

  bool get needsPhone => this != ContactType.email;
  bool get needsEmail => this != ContactType.phone;

  IconData get icon => switch (this) {
        ContactType.phone => Icons.phone_iphone_rounded,
        ContactType.email => Icons.mail_outline_rounded,
        ContactType.both => Icons.contact_phone_outlined,
      };
}

enum LeadSort { newest, complete, location }

extension LeadSortX on LeadSort {
  String get label => switch (this) {
        LeadSort.newest => 'Newest Leads',
        LeadSort.complete => 'Most Complete Contact Details',
        LeadSort.location => 'Location',
      };
}

const String kAllCategories = 'All Categories';
const String kOtherCategories = 'Other Categories';

/// Categories shown as their own chips. Anything else is "Other Categories".
const List<String> kMainCategories = [
  'Painters',
  'Plumbers',
  'Electricians',
  'Flooring Contractors',
  'Roofers',
  'HVAC Contractors',
  'Cleaning Services',
  'Real Estate',
  'Construction',
];

class Lead {
  final String id;
  final String company;
  final String contactName;
  final String jobTitle;
  final String phone;
  final String email;
  final String website;
  final String country;
  final String state;
  final String city;
  final String category;
  final DateTime dateAdded;
  final bool phoneVerified;
  final bool emailVerified;

  const Lead({
    required this.id,
    required this.company,
    required this.contactName,
    required this.jobTitle,
    required this.phone,
    required this.email,
    required this.website,
    required this.country,
    required this.state,
    required this.city,
    required this.category,
    required this.dateAdded,
    this.phoneVerified = false,
    this.emailVerified = false,
  });

  bool get hasPhone => phone.isNotEmpty;
  bool get hasEmail => email.isNotEmpty;
  bool get hasWebsite => website.isNotEmpty;

  /// Higher = more complete contact details (used by "Most Complete").
  int get completeness =>
      (hasPhone ? 1 : 0) +
      (hasEmail ? 1 : 0) +
      (hasWebsite ? 1 : 0) +
      (phoneVerified ? 1 : 0) +
      (emailVerified ? 1 : 0) +
      (contactName.isNotEmpty ? 1 : 0);

  /// Two leads with the same key are the same business.
  String get dedupeKey =>
      '${company.toLowerCase()}|${city.toLowerCase()}|${state.toLowerCase()}';

  String get location => '$city, $state';

  String get initials {
    final words = contactName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  /// A copy that only carries the contact fields the buyer paid for.
  Lead forType(ContactType t) => Lead(
        id: id,
        company: company,
        contactName: contactName,
        jobTitle: jobTitle,
        phone: t.needsPhone ? phone : '',
        email: t.needsEmail ? email : '',
        website: website,
        country: country,
        state: state,
        city: city,
        category: category,
        dateAdded: dateAdded,
        phoneVerified: t.needsPhone && phoneVerified,
        emailVerified: t.needsEmail && emailVerified,
      );
}

class LeadFilters {
  final String search;
  final String category;
  final ContactType type;
  final String country; // '' = any
  final String state; // '' = any
  final String city; // '' = any
  final bool website;
  final bool verifiedEmail;
  final bool verifiedPhone;
  final bool excludePurchased;
  final bool excludeDuplicates;
  final LeadSort sort;

  const LeadFilters({
    this.search = '',
    this.category = kAllCategories,
    this.type = ContactType.phone,
    this.country = '',
    this.state = '',
    this.city = '',
    this.website = false,
    this.verifiedEmail = false,
    this.verifiedPhone = false,
    this.excludePurchased = true,
    this.excludeDuplicates = true,
    this.sort = LeadSort.newest,
  });

  /// Short description used on orders, e.g. "Painters · Texas".
  String get summary {
    final place = city.isNotEmpty
        ? city
        : state.isNotEmpty
            ? state
            : country;
    return [
      category == kAllCategories ? 'All categories' : category,
      if (place.isNotEmpty) place,
    ].join(' · ');
  }
}

class PurchaseOrder {
  final String id;
  final ContactType type;
  final String summary;
  final List<Lead> leads;
  final int coins; // LeadCoins paid
  final DateTime createdAt;

  const PurchaseOrder({
    required this.id,
    required this.type,
    required this.summary,
    required this.leads,
    required this.coins,
    required this.createdAt,
  });

  String get title => '${type.shortLabel} leads · $summary';
}

// ---------------------------------------------------------------------------
// App state
// ---------------------------------------------------------------------------

/// Bottom navigation order.
const int kTabHome = 0;
const int kTabCampaigns = 1;
const int kTabMessages = 2;
const int kTabContacts = 3;
const int kTabMore = 4;

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}

class AppState extends ChangeNotifier {
  AppState() {
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) => _tick());
  }

// Public helper method to safely trigger listeners externally
  void notify() {
    notifyListeners();
  }
  Timer? _timer;
  final Random _rnd = Random();

  // Session
  bool signedIn = false;
  String userName = '';
  String userEmail = '';
  int tab = 0;
  bool loading = false;
  String? syncError;

// Money: three separate systems that never mix.
  int coins = 0; // LeadCoins (LeadMarket only)
  bool subscriptionActive = false; // LeadText subscription
  bool hasClaimedProBonus = false; // Tracks one-time Pro welcome bonus
  ProviderConnection? provider; // Telnyx balance lives with Telnyx
  DateTime? periodEnd; // end of the paid subscription period
  bool telnyxWebhookOk = false; // replies reach the Messages tab
  bool telnyxKeyInvalid = false; // Telnyx rejected the saved key
  int _sending = 0; // in-flight sends (pauses background refresh)
  bool _polling = false;
  int _tickN = 0;

  // Telnyx balance (demo). The live app reads this from the Telnyx API
  // through the backend; the API key never lives on the device.
  double telnyxBalance = 0;
  DateTime? balanceCheckedAt;
  bool refreshingBalance = false;

  final List<Contact> contacts = [];
  final List<PurchaseOrder> orders = [];
  final List<LedgerEntry> ledger = [];

  final List<Campaign> campaigns = [];
  final List<Conversation> conversations = [];

  void _run(Future<void> Function() job) {
    job().catchError((Object e) {
      debugPrint('Supabase sync failed: $e');
      syncError = e.toString();
      notifyListeners();
    });
  }

  Future<void> bootstrap() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    loading = true;
    notifyListeners();
    try {
      final p = await SupabaseService.fetchProfile();
      userEmail = (p?['email'] as String?) ?? user.email ?? '';
      final fullName = ((p?['full_name'] as String?) ?? '').trim();
      userName = fullName.isNotEmpty ? fullName : _nameFromEmail(userEmail);
      coins = (p?['coins'] as num?)?.toInt() ?? 0;

      final loadedContacts = await SupabaseService.fetchContacts();
      final loadedCampaigns = await SupabaseService.fetchCampaigns();
      final loadedConvos = await SupabaseService.fetchConversations();

      contacts
        ..clear()
        ..addAll(loadedContacts);
      campaigns
        ..clear()
        ..addAll(loadedCampaigns);
      conversations
        ..clear()
        ..addAll(loadedConvos);

      await refreshBilling();
      unawaited(loadTelnyxStatus());

      signedIn = true;
      tab = 0;
      syncError = null;
    } catch (e) {
      debugPrint('Bootstrap failed: $e');
      syncError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ---- derived ----
  int get unreadCount => conversations.where((c) => c.unread).length;
  int get totalSent => campaigns.fold(0, (s, c) => s + c.sent);
  int get totalDelivered => campaigns.fold(0, (s, c) => s + c.delivered);
  int get totalFailed => campaigns.fold(0, (s, c) => s + c.failed);
  int get totalReplies => campaigns.fold(0, (s, c) => s + c.replies);
  int get activeCampaigns => campaigns.where((c) => c.isActive).length;
  int get smsContacts => contacts.where((c) => c.phone.isNotEmpty).length;
  int get emailContacts => contacts.where((c) => c.email.isNotEmpty).length;
  int recipientsFor(Channel ch) =>
      ch == Channel.sms ? smsContacts : emailContacts;

  bool get lowBalance =>
      provider != null && telnyxBalance < kLowBalanceThreshold;

  int get smsLeft => (telnyxBalance / smsPricePerSegment).floor();

  Conversation? conversationById(String id) {
    for (final c in conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Unique group names (or purchased list names when [lists] is true).
  List<String> groupNames({required bool lists}) {
    final seen = <String>{};
    final out = <String>[];
    for (final c in contacts) {
      if (c.group.isEmpty || c.isList != lists) continue;
      if (seen.add(c.group)) out.add(c.group);
    }
    return out;
  }

  bool _hasAddress(Contact c, Channel ch) =>
      ch == Channel.sms ? c.phone.isNotEmpty : c.email.isNotEmpty;

  /// Contacts in [group] ([null] = everyone) that can receive [ch].
  int countFor(String? group, Channel ch) => contacts
      .where((c) => _hasAddress(c, ch) && (group == null || c.group == group))
      .length;

  /// Unique contacts covered by the selected rows. '__all__' means everyone.
  int recipientsForSelection(Set<String> selected, Channel ch) {
    final keys = <String>{};
    for (final c in contacts) {
      if (!_hasAddress(c, ch)) continue;
      if (selected.contains('__all__') ||
          (c.group.isNotEmpty && selected.contains(c.group))) {
        keys.add(c.key);
      }
    }
    return keys.length;
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'there';
    return local[0].toUpperCase() + local.substring(1);
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    signedIn = false;
    userName = '';
    userEmail = '';
    coins = 0;
    subscriptionActive = false;
    periodEnd = null;
    provider = null;
    telnyxBalance = 0;
    balanceCheckedAt = null;
    telnyxWebhookOk = false;
    telnyxKeyInvalid = false;
    contacts.clear();
    campaigns.clear();
    conversations.clear();
    orders.clear();
    ledger.clear();
    tab = 0;
    notifyListeners();
  }

  void setTab(int index) {
    tab = index;
    notifyListeners();
  }

  // ---- contacts ----
  int addContacts(List<Contact> incoming) {
    final existing = contacts.map((c) => c.key).toSet();
    final fresh = incoming.where((c) => existing.add(c.key)).toList();
    contacts.insertAll(0, fresh);
    notifyListeners();
    _run(() => SupabaseService.saveContacts(fresh));
    return fresh.length;
  }

  void removeContact(Contact contact) {
    contacts.removeWhere((c) => c.key == contact.key);
    notifyListeners();
    _run(() => SupabaseService.deleteContact(contact));
  }

  // ---- messaging ----
  /// Sends a real SMS campaign. The server saves the campaign, queues every
  /// recipient and sends through the user's Telnyx account in the background.
  /// Returns null on success, or a readable error message.
  Future<String?> launchCampaign(Campaign campaign, List<String> addresses) async {
    campaign.status = CampaignStatus.sending;
    campaigns.insert(0, campaign);
    notifyListeners();
    _sending++;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'telnyx',
        body: {
          'action': 'send_campaign',
          'campaign_id': campaign.id,
          'name': campaign.name,
          'message': campaign.message,
          'subject': campaign.subject,
          'channel': campaign.channel.name,
          'addresses': addresses,
        },
      );
      final d = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      if (d['success'] != true) {
        throw Exception(d['error'] ?? 'The campaign could not be started.');
      }
      return null;
    } catch (e) {
      campaign.failed = campaign.recipients;
      campaign.status = CampaignStatus.completed;
      return friendlyError(e);
    } finally {
      _sending--;
      notifyListeners();
    }
  }

  Conversation sendMessage({
    required Channel channel,
    required String address,
    required String text,
    String name = '',
  }) {
    Conversation? convo;
    for (final c in conversations) {
      if (c.address == address && c.channel == channel) convo = c;
    }
    if (convo == null) {
      String resolved = name;
      if (resolved.isEmpty) {
        for (final c in contacts) {
          if (c.key == address) resolved = c.name;
        }
      }
      convo = Conversation(
        id: _uuid(),
        name: resolved,
        address: address,
        channel: channel,
        messages: [],
      );
      conversations.insert(0, convo);
    }
    final msg = ChatMessage(
      text: text,
      outbound: true,
      time: DateTime.now(),
      status: MessageStatus.sent,
    );
    convo.messages.add(msg);
    conversations.remove(convo);
    conversations.insert(0, convo);
    notifyListeners();
    _deliver(convo, msg);
    return convo;
  }

  /// Sends the message through Telnyx (server side). The server also saves it
  /// in the conversation, so the app only updates its own copy.
  Future<void> _deliver(Conversation convo, ChatMessage msg) async {
    _sending++;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'telnyx',
        body: {
          'action': 'send_sms',
          'to': convo.address,
          'text': msg.text,
          'name': convo.name,
          'conversation_id': convo.id,
        },
      );
      final d = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final ok = d['success'] == true;
      final index = convo.messages.indexOf(msg);
      if (index >= 0) {
        convo.messages[index] = ChatMessage(
          id: d['message_id'] as String?,
          text: msg.text,
          outbound: true,
          time: msg.time,
          status: ok ? MessageStatus.sent : MessageStatus.failed,
        );
      }
      if (!ok) _toast(d['error']?.toString() ?? 'The message could not be sent.');
    } catch (e) {
      msg.status = MessageStatus.failed;
      _toast(friendlyError(e));
    } finally {
      _sending--;
      notifyListeners();
    }
  }

  void _toast(String message) {
    kMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void markRead(Conversation convo) {
    if (!convo.unread) return;
    convo.unread = false;
    notifyListeners();
    _run(() => SupabaseService.markConversationRead(convo.id));
  }

  void editMessage(ChatMessage m, String text) {
    m.text = text;
    m.isEdited = true;
    notifyListeners();
    _run(() => SupabaseService.updateMessageText(m.id, text));
  }

  void deleteMessage(Conversation convo, ChatMessage m) {
    convo.messages.remove(m);
    notifyListeners();
    _run(() => SupabaseService.deleteMessage(m.id));
  }

  void editConversationContact(Conversation convo, String name, String address) {
    convo.name = name;
    convo.address = address;
    notifyListeners();
    _run(() => SupabaseService.updateConversationContact(
          convo.id,
          name: name,
          address: address,
        ));
  }

  void deleteConversation(Conversation convo) {
    conversations.removeWhere((c) => c.id == convo.id);
    notifyListeners();
    _run(() => SupabaseService.deleteConversation(convo.id));
  }

  // ---- LeadCoins ----
  void buyCoins(CoinBundle bundle) {
    coins += bundle.coins;
    ledger.insert(
      0,
      LedgerEntry(
        title: 'Bought ${bundle.coins} LeadCoins',
        amount: bundle.coins,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // ---- LeadMarket ----
  Set<String> get purchasedLeadIds => {
        for (final o in orders)
          for (final l in o.leads) l.id,
      };

  /// Runs a LeadMarket search over the inventory.
  ///
  /// RULE: Email + Phone returns only businesses that have BOTH fields.
  /// Phone Only needs a phone, Email Only needs an email.
  List<Lead> searchLeads(LeadFilters f) {
    final bought = f.excludePurchased ? purchasedLeadIds : const <String>{};
    final q = f.search.trim().toLowerCase();
    final needPhone = f.type.needsPhone;
    final needEmail = f.type.needsEmail;

    final matches = kLeadInventory.where((l) {
      if (needPhone && !l.hasPhone) return false;
      if (needEmail && !l.hasEmail) return false;
      if (f.verifiedPhone && needPhone && !l.phoneVerified) return false;
      if (f.verifiedEmail && needEmail && !l.emailVerified) return false;
      if (f.website && !l.hasWebsite) return false;
      if (bought.contains(l.id)) return false;

      if (f.category == kOtherCategories) {
        if (kMainCategories.contains(l.category)) return false;
      } else if (f.category != kAllCategories && l.category != f.category) {
        return false;
      }

      if (f.country.isNotEmpty && l.country != f.country) return false;
      if (f.state.isNotEmpty && l.state != f.state) return false;
      if (f.city.isNotEmpty && l.city != f.city) return false;

      if (q.isNotEmpty) {
        final hay =
            '${l.company} ${l.contactName} ${l.jobTitle} ${l.category} ${l.website}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    switch (f.sort) {
      case LeadSort.newest:
        matches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case LeadSort.complete:
        matches.sort((a, b) {
          final c = b.completeness.compareTo(a.completeness);
          return c != 0 ? c : b.dateAdded.compareTo(a.dateAdded);
        });
      case LeadSort.location:
        matches.sort((a, b) {
          var c = a.country.compareTo(b.country);
          if (c != 0) return c;
          c = a.state.compareTo(b.state);
          if (c != 0) return c;
          return a.city.compareTo(b.city);
        });
    }

    if (!f.excludeDuplicates) return matches;
    final seen = <String>{};
    return matches.where((l) => seen.add(l.dedupeKey)).toList();
  }

  /// Idempotent: the same [orderId] can never be charged twice. Returns null
  /// when the balance is too low, and nothing is deducted.
  PurchaseOrder? purchase({
    required ContactType type,
    required String summary,
    required List<Lead> leads,
    required String orderId,
  }) {
    for (final o in orders) {
      if (o.id == orderId) return o;
    }
    final cost = leadCoinsFor(type, leads.length);
    if (leads.isEmpty || coins < cost) return null;

    final order = PurchaseOrder(
      id: orderId,
      type: type,
      summary: summary,
      coins: cost,
      leads: [for (final l in leads) l.forType(type)],
      createdAt: DateTime.now(),
    );
    coins -= cost;
    orders.insert(0, order);
    ledger.insert(
      0,
      LedgerEntry(
        title: '${order.title} · $orderId',
        amount: -cost,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
    return order;
  }

  int importOrderToContacts(PurchaseOrder order) {
    final t = order.type;
    final incoming = <Contact>[
      for (final lead in order.leads)
        if ((t.needsPhone && lead.hasPhone) || (t.needsEmail && lead.hasEmail))
          Contact(
            name: lead.contactName,
            phone: t.needsPhone ? lead.phone : '',
            email: t.needsEmail ? lead.email : '',
            group: order.title,
            isList: true,
          ),
    ];
    return addContacts(incoming);
  }

  // ---- billing ----
  /// Reads coins and subscription status straight from the server (the source
  /// of truth). Called after sign-in and after a payment.
  Future<void> refreshBilling() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('coins, subscription_status, current_period_end')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        coins = (row['coins'] as num?)?.toInt() ?? coins;
        final status = row['subscription_status'] as String? ?? 'inactive';
        final end = row['current_period_end'] as String?;
        periodEnd = end == null ? null : DateTime.tryParse(end)?.toLocal();
        subscriptionActive = (status == 'active' || status == 'trialing') &&
            (periodEnd == null || periodEnd!.isAfter(DateTime.now()));
      }
    } catch (e) {
      debugPrint('Billing refresh failed: $e');
    }
    notifyListeners();
  }

  // ---- Telnyx (every call goes through the `telnyx` Edge Function) ----
  Future<void> loadTelnyxStatus() async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'telnyx',
        body: {'action': 'status'},
      );
      final d = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      if (d['connected'] == true) {
        provider = ProviderConnection(
          maskedKey: (d['masked_key'] as String?) ?? '',
          smsNumber: (d['sms_number'] as String?) ?? '',
        );
        telnyxWebhookOk = d['webhook_registered'] == true;
        telnyxKeyInvalid = d['key_invalid'] == true;
        final bal = d['balance'];
        if (bal is num) {
          telnyxBalance = bal.toDouble();
          balanceCheckedAt = DateTime.now();
        }
      } else {
        clearTelnyx(notify: false);
      }
    } catch (e) {
      debugPrint('Telnyx status failed: $e');
    }
    notifyListeners();
  }

  void clearTelnyx({bool notify = true}) {
    provider = null;
    telnyxBalance = 0;
    balanceCheckedAt = null;
    telnyxWebhookOk = false;
    telnyxKeyInvalid = false;
    if (notify) notifyListeners();
  }

  /// Reads the real balance from Telnyx (through the Edge Function).
  Future<void> refreshBalance() async {
    if (provider == null || refreshingBalance) return;
    refreshingBalance = true;
    notifyListeners();
    await loadTelnyxStatus();
    refreshingBalance = false;
    notifyListeners();
  }

  // ---- background refresh (campaign progress + incoming replies) ----
  Future<void> _refreshCampaigns() async {
    _polling = true;
    try {
      final fresh = await SupabaseService.fetchCampaigns();
      final ids = {for (final c in fresh) c.id};
      final localOnly = campaigns.where((c) => !ids.contains(c.id)).toList();
      campaigns
        ..clear()
        ..addAll([...localOnly, ...fresh])
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('Campaign refresh failed: $e');
    } finally {
      _polling = false;
    }
  }

  Future<void> _refreshConversations() async {
    _polling = true;
    try {
      final fresh = await SupabaseService.fetchConversations();
      final ids = {for (final c in fresh) c.id};
      final localOnly = conversations.where((c) => !ids.contains(c.id)).toList();
      conversations
        ..clear()
        ..addAll([...localOnly, ...fresh]);
      notifyListeners();
    } catch (e) {
      debugPrint('Conversation refresh failed: $e');
    } finally {
      _polling = false;
    }
  }

  // ---- demo delivery simulation ----
  void _tick() {
    _tickN++;
    if (signedIn && !_polling && _sending == 0) {
      if (_tickN % 5 == 0 && campaigns.any((c) => c.isActive && !c.demoSim)) {
        _refreshCampaigns();
      } else if (_tickN % 9 == 0) {
        _refreshConversations();
      }
    }
    var changed = false;
    for (final c in campaigns) {
      if (!c.isActive || !c.demoSim) continue;
      changed = true;
      if (c.status == CampaignStatus.queued) {
        c.status = CampaignStatus.sending;
        continue;
      }
      final remaining = c.recipients - c.sent;
      final step = min(remaining, max(1, (c.recipients * 0.06).round()));
      final failed = (step * 0.03).round();
      c.failed += failed;
      c.delivered += step - failed;
      if (c.channel == Channel.email) {
        c.opened = min(c.delivered, c.opened + ((step - failed) * 0.4).round());
      }
      if (c.channel == Channel.sms && provider != null) {
        telnyxBalance = max(
          0.0,
          telnyxBalance - step * c.segments * smsPricePerSegment,
        );
      }
      if (_rnd.nextInt(3) == 0) c.replies += 1;
      if (c.sent >= c.recipients) {
        c.status = CampaignStatus.completed;
        _run(() => SupabaseService.setCampaignStatus(c.id, CampaignStatus.completed));
      }
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Paste parser
// ---------------------------------------------------------------------------

class ParseResult {
  final List<Contact> contacts;
  final int duplicates;
  final int invalid;

  const ParseResult({
    required this.contacts,
    required this.duplicates,
    required this.invalid,
  });

  static const ParseResult empty =
      ParseResult(contacts: [], duplicates: 0, invalid: 0);
}

const String defaultCountryCode = '1';

final RegExp _candidateRegex = RegExp(r'\+?\(?\d[\d\s().\-]{5,}\d');
final RegExp _nonDigit = RegExp(r'\D');

String? _normalizePhone(String raw) {
  final hasPlus = raw.trim().startsWith('+');
  final digits = raw.replaceAll(_nonDigit, '');
  if (digits.length < 8 || digits.length > 15) return null;
  if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return null;
  if (hasPlus) return '+$digits';
  if (digits.length == 10) return '+$defaultCountryCode$digits';
  return '+$digits';
}

List<String> _splitCandidate(String text) {
  final out = <String>[];
  for (final piece in text.trim().split(RegExp(r'\s+(?=\+)'))) {
    final digitCount = piece.replaceAll(_nonDigit, '').length;
    if (digitCount > 15) {
      out.addAll(piece.split(RegExp(r'\s+')).where((t) => t.isNotEmpty));
    } else {
      out.add(piece);
    }
  }
  return out;
}

String _cleanName(String input) {
  final cleaned = input.replaceAll(
    RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}.]+$', unicode: true),
    '',
  );
  if (cleaned.length > 40) return '';
  return RegExp(r'\p{L}', unicode: true).hasMatch(cleaned) ? cleaned : '';
}

/// Finds phone numbers and email addresses (with optional names) in pasted
/// text. Cleans formatting, drops duplicates (also against [existing]) and
/// skips obviously invalid entries.
ParseResult parseContacts(String raw, {Set<String> existing = const {}}) {
  final seen = <String>{...existing};
  final contacts = <Contact>[];
  var duplicates = 0;
  var invalid = 0;

  for (final segment in raw.split(RegExp(r'[\r\n;,\t|]+'))) {
    if (segment.trim().isEmpty) continue;

    final emailMatch = _emailRegex.firstMatch(segment);
    if (emailMatch != null) {
      final email = emailMatch.group(0)!.toLowerCase();
      final name = _cleanName(
        segment.replaceFirst(emailMatch.group(0)!, ' '),
      );
      if (!seen.add(email)) {
        duplicates++;
      } else {
        contacts.add(Contact(name: name, email: email));
      }
      continue;
    }

    final matches = _candidateRegex.allMatches(segment).toList();
    if (matches.isEmpty) {
      if (RegExp(r'\d').hasMatch(segment)) invalid++;
      continue;
    }

    var cursor = 0;
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      var name = _cleanName(segment.substring(cursor, match.start));
      cursor = match.end;
      if (i == matches.length - 1 && name.isEmpty) {
        name = _cleanName(segment.substring(match.end));
      }

      final parts = _splitCandidate(match.group(0)!);
      for (var j = 0; j < parts.length; j++) {
        final phone = _normalizePhone(parts[j]);
        if (phone == null) {
          invalid++;
          continue;
        }
        if (!seen.add(phone)) {
          duplicates++;
          continue;
        }
        contacts.add(Contact(name: j == 0 ? name : '', phone: phone));
      }
    }
  }

  return ParseResult(
    contacts: contacts,
    duplicates: duplicates,
    invalid: invalid,
  );
}

// ---------------------------------------------------------------------------
// App + theme
// ---------------------------------------------------------------------------

class LeadTextApp extends StatefulWidget {
  const LeadTextApp({super.key});

  @override
  State<LeadTextApp> createState() => _LeadTextAppState();
}

class _LeadTextAppState extends State<LeadTextApp> {
  final AppState state = AppState();

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kLine),
    );

    return MaterialApp(
      title: 'LeadText',
      scaffoldMessengerKey: kMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kBg,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 14, color: kText),
          bodyMedium: TextStyle(fontSize: 13, color: kText),
          bodySmall: TextStyle(fontSize: 11.5, color: kMuted),
          titleMedium: TextStyle(fontSize: 14, color: kText),
          titleSmall: TextStyle(fontSize: 13, color: kText),
          labelLarge: TextStyle(fontSize: 13),
        ),
        colorScheme: const ColorScheme.light(
          primary: kAccent,
          onPrimary: Colors.white,
          secondary: kAccentBright,
          surface: kSurface,
          onSurface: kText,
          error: kRed,
        ),
        splashFactory: InkRipple.splashFactory,
        dividerTheme: const DividerThemeData(
          color: kLine,
          thickness: 1,
          space: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          foregroundColor: kText,
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kText,
            letterSpacing: -0.2,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 62,
          backgroundColor: kSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: const Color(0xFFE8EDFF),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? kAccent : kFaint,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 22,
              color: selected ? kAccent : kFaint,
            );
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurface,
          hintStyle: const TextStyle(color: kFaint, fontSize: 13),
          prefixIconColor: kFaint,
          suffixIconColor: kFaint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kAccentBright, width: 1.2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kSurfaceHi,
            disabledForegroundColor: kFaint,
            minimumSize: const Size(64, 46),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kText,
            minimumSize: const Size(64, 46),
            side: const BorderSide(color: kLine),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kAccentBright,
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: kSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          textStyle: const TextStyle(fontSize: 13, color: kText),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: kLine),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF172033),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: kLine),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kSurface,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          dragHandleColor: kLine,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? kAccent : const Color(0xFFCBD5E1),
          ),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = (mq.textScaler.scale(1.0) * kTextScale)
            .clamp(0.8, 1.4)
            .toDouble();
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: AppScope(state: state, child: child!),
        );
      },
      home: const SplashGate(child: RootGate()),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: state.signedIn
          ? const MainScreen(key: ValueKey('main'))
          : const AuthPage(key: ValueKey('auth')),
    );
  }
}

// ---------------------------------------------------------------------------
// Splash screen
// ---------------------------------------------------------------------------

/// Shows [SplashPage] first, then fades into [child].
class SplashGate extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const SplashGate({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2600),
  });

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      child: _done
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : const SplashPage(key: ValueKey('splash')),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  late final Animation<double> _logoScale = Tween<double>(begin: 0.7, end: 1)
      .animate(CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
  ));

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
  );

  // Two soft rings that expand from behind the logo and fade out.
  late final Animation<double> _ringA = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.15, 0.8, curve: Curves.easeOut),
  );
  late final Animation<double> _ringB = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.3, 0.95, curve: Curves.easeOut),
  );

  late final Animation<double> _wordFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.28, 0.6, curve: Curves.easeOut),
  );

  late final Animation<Offset> _wordSlide =
      Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0.28, 0.6, curve: Curves.easeOutCubic),
    ),
  );

  late final Animation<double> _tagFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
  );

  late final Animation<double> _footFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _ring(Animation<double> a) {
    final t = a.value;
    return Opacity(
      opacity: ((1 - t) * 0.5).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.75 + t * 0.9,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: kAccentBright.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.0,
            colors: [Color(0xFFE3EAFF), kBg],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Column(
                children: [
                  const Spacer(flex: 5),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _ring(_ringA),
                        _ring(_ringB),
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: kAccent.withValues(alpha: 0.25),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: const LogoMark(size: 92),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _wordFade,
                    child: SlideTransition(
                      position: _wordSlide,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.1,
                          ),
                          children: [
                            TextSpan(text: 'Lead', style: TextStyle(color: kText)),
                            TextSpan(text: 'Text', style: TextStyle(color: kAccent)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _tagFade,
                    child: const Text(
                      'SMS & email outreach, made simple.',
                      style: TextStyle(fontSize: 13, color: kMuted, letterSpacing: 0.1),
                    ),
                  ),
                  const Spacer(flex: 4),
                  SizedBox(
                    width: 96,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _c.value,
                        minHeight: 3,
                        backgroundColor: kLine,
                        color: kAccentBright,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FadeTransition(
                    opacity: _footFade,
                    child: const Text(
                      'A JML Product',
                      style: TextStyle(fontSize: 11.5, color: kFaint, letterSpacing: 0.3),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      elevation: 1,
      shadowColor: const Color(0x0A0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    this.color = kAccentBright,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;

  const Pill(this.label, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: h2)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kAccentBright,
              ),
            ),
          ),
      ],
    );
  }
}

/// Fixed page title. Always place it OUTSIDE the scrolling list so it stays
/// pinned at the top.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: h1),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: bodyMuted),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: kSurface,
        shape: const CircleBorder(side: BorderSide(color: kLine)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: kText),
          ),
        ),
      ),
    );
  }
}

class ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null
          ? null
          : Icon(icon, size: 15, color: selected ? Colors.white : kMuted),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: kSurface,
      selectedColor: kAccent,
      shape: const StadiumBorder(),
      side: BorderSide(color: selected ? kAccent : kLine),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : kMuted,
      ),
    );
  }
}

/// Rounded segmented tabs (All / SMS / Email, SMS / Email, All / Groups / Lists).
class SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SegmentTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLine),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? kAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: i == index ? Colors.white : kMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: kMuted,
        letterSpacing: 0.2,
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: kMuted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? kText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoBullet({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 17, color: kAccentBright),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: kMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: icon, size: 52),
            const SizedBox(height: 14),
            Text(title, style: h2),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: bodyMuted),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String initials;
  final double radius;
  final IconData fallback;

  const Avatar({
    super.key,
    required this.initials,
    this.radius = 20,
    this.fallback = Icons.person_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: kSurfaceHi,
      child: initials.isEmpty
          ? Icon(fallback, size: radius * 0.95, color: kAccentBright)
          : Text(
              initials,
              style: TextStyle(
                color: kText,
                fontSize: radius * 0.66,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

/// Returns false (and tells the user) when the subscription is inactive.
bool requireSubscription(BuildContext context) {
  final state = AppScope.of(context);
  if (state.subscriptionActive) return true;
  showSubscriptionSheet(context);
  return false;
}

/// Only SMS can be sent (through Telnyx). Email is not available yet.
bool requireSms(BuildContext context, Channel channel) {
  if (channel == Channel.sms) return true;
  showToast(context, 'Email sending is not available yet. SMS is live through Telnyx.');
  return false;
}

/// Returns false (and opens the Telnyx page) when Telnyx is not connected,
/// because nothing can be delivered without it.
bool requireProvider(BuildContext context) {
  final state = AppScope.of(context);
  if (state.provider != null) return true;
  showToast(context, 'Connect your Telnyx account first so messages can be delivered.');
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const TelnyxPage()),
  );
  return false;
}

/// Copies the Telnyx portal link. The live app opens it with url_launcher.
Future<void> addTelnyxFunds(BuildContext context) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse('https://portal.telnyx.com'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
  if (opened) return;
  await Clipboard.setData(const ClipboardData(text: 'https://portal.telnyx.com'));
  if (!context.mounted) return;
  showToast(
    context,
    'Telnyx portal link copied. Add funds there, then tap Refresh.',
  );
}

// ---------------------------------------------------------------------------
// Auth (demo)
// ---------------------------------------------------------------------------

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool registering = false;
  bool hidePassword = true;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (registering && nameController.text.trim().isEmpty) {
      setState(() => error = 'Please enter your name.');
      return;
    }
    if (!isValidEmail(email)) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(() => error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      error = null;
      busy = true;
    });

    try {
      if (registering) {
        await SupabaseService.signUp(
          email: email,
          password: password,
          fullName: nameController.text.trim(),
        );
      } else {
        await SupabaseService.signIn(email: email, password: password);
      }
      if (!mounted) return;
      await AppScope.of(context).bootstrap();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Something went wrong. Check your connection and try again.';
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LogoMark(size: 56),
                  const SizedBox(height: 24),
                  Text(
                    registering ? 'Create your account' : 'Welcome back',
                    style: h1.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Send SMS and email campaigns and answer replies, all in one place.',
                    style: bodyMuted,
                  ),
                  const SizedBox(height: 24),
                  if (registering) ...[
                    const FieldLabel('Name'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Your name'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const FieldLabel('Email'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: 'you@company.com'),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Password'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    onSubmitted: (_) => busy ? null : _submit(),
                    decoration: InputDecoration(
                      hintText: 'At least 8 characters',
                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                        ),
                        onPressed: () =>
                            setState(() => hidePassword = !hidePassword),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(fontSize: 12, color: kRed),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(registering ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        registering = !registering;
                        error = null;
                      }),
                      child: Text(
                        registering
                            ? 'I already have an account'
                            : 'Create an account',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'By continuing you agree to our terms.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: kFaint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main shell: Home, Campaigns, Messages, Contacts, More
// ---------------------------------------------------------------------------

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.of(context);
      if (!state.subscriptionActive) {
        showSubscriptionSheet(context);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: state.tab,
          children: [
            const HomeTab(),
            const CampaignsTab(),
            const InboxTab(),
            if (kLeadMarketEnabled) const LeadMarketTab() else const ContactsPage(),
            const MoreTab(),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kLine)),
        ),
        child: NavigationBar(
          selectedIndex: state.tab,
          onDestinationSelected: state.setTab,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.send_outlined),
              selectedIcon: Icon(Icons.send_rounded),
              label: 'Campaigns',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: state.unreadCount > 0,
                label: Text('${state.unreadCount}'),
                backgroundColor: kAccent,
                textColor: Colors.white,
                child: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: state.unreadCount > 0,
                label: Text('${state.unreadCount}'),
                backgroundColor: kAccent,
                textColor: Colors.white,
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(
                kLeadMarketEnabled
                    ? Icons.storefront_outlined
                    : Icons.people_outline_rounded,
              ),
              selectedIcon: Icon(
                kLeadMarketEnabled
                    ? Icons.storefront_rounded
                    : Icons.people_rounded,
              ),
              label: kLeadMarketEnabled ? 'LeadMarket' : 'Contacts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              selectedIcon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 17) return 'Good afternoon,';
  return 'Good evening,';
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final firstName =
        state.userName.isEmpty ? 'there' : state.userName.split(' ').first;

    return Column(
      children: [
        // Fixed top bar
        Container(
          color: kBg,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Row(
            children: [
              const LogoMark(size: 28),
              const SizedBox(width: 10),
              const Text(
                'LeadText',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kText,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (!state.subscriptionActive) ...[
                GestureDetector(
                  onTap: () => showSubscriptionSheet(context),
                  child: const Pill('Subscription inactive', color: kAmber),
                ),
                const SizedBox(width: 12),
              ],
              GestureDetector(
                onTap: () => state.setTab(kTabMessages),
                child: Badge(
                  isLabelVisible: state.unreadCount > 0,
                  smallSize: 9,
                  backgroundColor: kAccentBright,
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 23,
                    color: kText,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => state.setTab(kTabMore),
                child: Avatar(
                  radius: 16,
                  initials:
                      state.userName.isEmpty ? '' : state.userName[0].toUpperCase(),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Text(_greeting(), style: bodyMuted),
              const SizedBox(height: 2),
              Text(firstName, style: h1.copyWith(fontSize: 26)),
              const SizedBox(height: 16),

              const _BalanceCard(),
              const SizedBox(height: 12),
              const _Snapshot(),
              const SizedBox(height: 12),
              const _QuickActions(),

              const SizedBox(height: 12),
              const _TelnyxRow(),

              const SizedBox(height: 24),
              SectionHeader(
                title: 'Recent activity',
                actionLabel: 'Campaigns',
                onAction: () => state.setTab(kTabCampaigns),
              ),
              const SizedBox(height: 10),
              const _RecentActivity(),
              const SizedBox(height: 24),

              const SectionHeader(title: 'LeadMarket'),
              const SizedBox(height: 10),
              const _MarketBanner(),
              const SizedBox(height: 24),

              const AdsCarousel(),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Recommended tools'),
              const SizedBox(height: 10),
              const _ToolsList(),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.info_outline_rounded, size: 14, color: kFaint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kLeadMarketEnabled
                          ? 'Your subscription, LeadCoins and Telnyx balance are three '
                              'separate things. LeadCoins cannot pay for messaging.'
                          : 'Messages are billed by Telnyx to your own account. Your '
                              'LeadText subscription is separate.',
                      style: const TextStyle(fontSize: 11.5, color: kFaint, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Below this many LeadCoins the card shows "Low balance"
/// (15 = the cheapest 1,000-lead pack).
const int kLowCoinsThreshold = 15;

// ---- LeadCoins hero ----

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final low = state.coins < kLowCoinsThreshold;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2542FF), kAccent, Color(0xFF0A1240)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.toll_rounded, color: Colors.white70, size: 17),
              const SizedBox(width: 8),
              const Text(
                'LeadCoins',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              if (low)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Low balance',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatCount(state.coins),
            style: const TextStyle(
              fontSize: 38,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.3,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '≈ ${formatMoney(state.coins.toDouble())} of LeadMarket credit · 1 LC = \$1',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletPage()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kAccent,
              minimumSize: const Size.fromHeight(42),
            ),
            child: const Text('Top up balance'),
          ),
        ],
      ),
    );
  }
}

// ---- Compact Telnyx row (the Telnyx balance moved here from the hero) ----

class _TelnyxRow extends StatelessWidget {
  const _TelnyxRow();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final connected = state.provider != null;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TelnyxPage()),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.cell_tower_rounded,
            color: !connected
                ? kAmber
                : state.lowBalance
                    ? kAmber
                    : kGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Telnyx balance', style: rowTitle),
                const SizedBox(height: 2),
                Text(
                  !connected
                      ? 'Not connected · tap to connect'
                      : state.lowBalance
                          ? 'Running low · add funds in Telnyx'
                          : '≈ ${formatCount(state.smsLeft)} SMS left',
                  style: rowSub,
                ),
              ],
            ),
          ),
          if (connected)
            Text(
              formatMoney(state.telnyxBalance),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: state.lowBalance ? kAmber : kText,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: kFaint),
        ],
      ),
    );
  }
}

// ---- Sending snapshot ----

class _Snapshot extends StatelessWidget {
  const _Snapshot();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    int sentBy(Channel ch) => state.campaigns
        .where((c) => c.channel == ch)
        .fold(0, (s, c) => s + c.sent);

    final sent = state.totalSent;
    final rate =
        sent == 0 ? '—' : '${(state.totalDelivered / sent * 100).round()}%';

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          Expanded(child: _Mini('SMS sent', formatCount(sentBy(Channel.sms)))),
          const _Sep(),
          Expanded(child: _Mini('Emails sent', formatCount(sentBy(Channel.email)))),
          const _Sep(),
          Expanded(child: _Mini('Replies', formatCount(state.totalReplies))),
          const _Sep(),
          Expanded(child: _Mini('Delivery', rate)),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: kLine);
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;

  const _Mini(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kText,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: kMuted)),
      ],
    );
  }
}

// ---- Quick actions ----

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Row(
      children: [
        Expanded(
          child: _Action(
            icon: Icons.add_rounded,
            label: 'Campaign',
            onTap: () {
              if (!requireSubscription(context)) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewCampaignPage()),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Action(
            icon: Icons.edit_outlined,
            label: 'Message',
            onTap: () => showComposeSheet(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Action(
            icon: Icons.people_outline_rounded,
            label: 'Contacts',
            onTap: () {
              if (!kLeadMarketEnabled) {
                state.setTab(kTabContacts); // Contacts is a tab while LeadMarket is off
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactsPage()),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Action(
            icon: Icons.cell_tower_rounded,
            label: 'Telnyx',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TelnyxPage()),
            ),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(icon, size: 21, color: kAccentBright),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: kText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- LeadMarket banner ----

class _MarketBanner extends StatelessWidget {
  const _MarketBanner();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLine),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFE9EEFF)],
          ),
        ),
        child: InkWell(
          onTap: () {
            if (kLeadMarketEnabled) {
              state.setTab(kTabContacts);
            } else {
              showToast(context, 'LeadMarket is opening soon.');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 46, color: kAccent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Shop for leads', style: h2),
                          if (!kLeadMarketEnabled) ...[
                            const SizedBox(width: 8),
                            const Pill('Soon', color: kAmber),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Buy business phone numbers and emails at the cheapest price.',
                        style: rowSub,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Recent activity ----

class _Activity {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final DateTime time;
  final VoidCallback onTap;

  const _Activity({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.time,
    required this.onTap,
  });
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = <_Activity>[];

    for (final c in state.campaigns) {
      final done = c.status == CampaignStatus.completed;
      items.add(
        _Activity(
          icon: c.channel.icon,
          color: done ? kGreen : kAccentBright,
          title: c.name,
          sub: done
              ? 'Completed · ${formatCount(c.delivered)} delivered · '
                  '${formatCount(c.failed)} failed'
              : 'Sending · ${(c.progress * 100).round()}% of '
                  '${formatCount(c.recipients)}',
          time: c.createdAt,
          onTap: () => state.setTab(kTabCampaigns),
        ),
      );
    }

    for (final convo in state.conversations) {
      final m = convo.last;
      if (m.outbound) continue;
      items.add(
        _Activity(
          icon: Icons.chat_bubble_outline_rounded,
          color: kAmber,
          title: 'Reply from ${convo.title}',
          sub: m.text,
          time: m.time,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ConversationPage(id: convo.id)),
          ),
        ),
      );
    }

    items.sort((a, b) => b.time.compareTo(a.time));
    final shown = items.take(5).toList();

    if (shown.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.all(18),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            'Nothing yet. Send a campaign and replies will show up here.',
            textAlign: TextAlign.center,
            style: bodyMuted,
          ),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(),
            InkWell(
              onTap: shown[i].onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconBadge(icon: shown[i].icon, color: shown[i].color, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shown[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rowTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shown[i].sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rowSub,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(shown[i].time),
                      style: const TextStyle(fontSize: 10.5, color: kFaint),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Ads carousel ----

class _AdItem {
  final String title;
  final String body;
  final String cta;
  final IconData icon;
  final List<Color> colors;

  const _AdItem({
    required this.title,
    required this.body,
    required this.cta,
    required this.icon,
    required this.colors,
  });
}

const List<_AdItem> _ads = [
  _AdItem(
    title: 'Need a website or automation?',
    body: 'Get custom websites, n8n workflows and AI solutions from JML.',
    cta: 'Learn more',
    icon: Icons.web_rounded,
    colors: [Color(0xFF2542FF), kAccent, Color(0xFF0A1240)],
  ),
  _AdItem(
    title: 'Find and verify B2B leads',
    body: 'Apollo.io helps you build targeted prospect lists.',
    cta: 'Visit Apollo.io',
    icon: Icons.travel_explore_rounded,
    colors: [Color(0xFF4F46E5), Color(0xFF3730A3), Color(0xFF1E1B4B)],
  ),
  _AdItem(
    title: 'Email warm-up and deliverability',
    body: 'Instantly keeps your emails out of the spam folder.',
    cta: 'Visit Instantly',
    icon: Icons.bolt_rounded,
    colors: [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF042F2E)],
  ),
];

class AdsCarousel extends StatefulWidget {
  const AdsCarousel({super.key});

  @override
  State<AdsCarousel> createState() => _AdsCarouselState();
}

class _AdsCarouselState extends State<AdsCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _ads.length,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            itemCount: _ads.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _AdCard(ad: _ads[i]),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _ads.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? kAccentBright : kLine,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AdCard extends StatelessWidget {
  final _AdItem ad;

  const _AdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showToast(context, 'Partner links open here once ads go live.'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ad.colors,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POWERED BY JML',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ad.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ad.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ad.cta,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: kAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 13, color: kAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(ad.icon, size: 40, color: Colors.white.withValues(alpha: 0.85)),
          ],
        ),
      ),
    );
  }
}

// ---- Recommended tools ----

class _ToolsList extends StatelessWidget {
  const _ToolsList();

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
  }) {
    return InkWell(
      onTap: () => showToast(context, 'Partner links open here once ads go live.'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: rowTitle),
                  const SizedBox(height: 2),
                  Text(sub, style: rowSub),
                ],
              ),
            ),
            const Pill('Partner', color: kAccentBright),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _row(
            context,
            icon: Icons.travel_explore_rounded,
            color: kGreen,
            title: 'Apollo.io',
            sub: 'Find & verify B2B leads',
          ),
          const Divider(),
          _row(
            context,
            icon: Icons.bolt_rounded,
            color: kAccentBright,
            title: 'Instantly',
            sub: 'Email warm-up & deliverability',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages (inbox)
// ---------------------------------------------------------------------------

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  static const filters = ['All', 'SMS', 'Email', 'Unread'];
  final searchController = TextEditingController();
  int filter = 0;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final query = searchController.text.trim().toLowerCase();
    final list = state.conversations.where((c) {
      if (query.isNotEmpty &&
          !c.title.toLowerCase().contains(query) &&
          !c.address.toLowerCase().contains(query) &&
          !c.last.text.toLowerCase().contains(query)) {
        return false;
      }
      switch (filters[filter]) {
        case 'SMS':
          return c.channel == Channel.sms;
        case 'Email':
          return c.channel == Channel.email;
        case 'Unread':
          return c.unread;
        default:
          return true;
      }
    }).toList();

    return Stack(
      children: [
        Column(
          children: [
            PageHeader(
              title: 'Messages',
              subtitle: state.unreadCount == 0
                  ? 'You are all caught up.'
                  : '${state.unreadCount} unread',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search conversations…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17),
                          onPressed: () {
                            searchController.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: SegmentTabs(
                labels: filters,
                index: filter,
                onChanged: (i) => setState(() => filter = i),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: state.conversations.isEmpty
                          ? 'No conversations yet'
                          : 'Nothing here',
                      message: state.conversations.isEmpty
                          ? 'Replies from your campaigns and messages show up here.'
                          : 'No conversations match.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) => _ConversationTile(convo: list[i]),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: Material(
            color: kAccent,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: kAccent.withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showComposeSheet(context),
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(Icons.edit_outlined, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation convo;

  const _ConversationTile({required this.convo});

  @override
  Widget build(BuildContext context) {
    final last = convo.last;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ConversationPage(id: convo.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(initials: convo.initials, radius: 21),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: kBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBg, width: 2),
                    ),
                    child: Icon(convo.channel.icon, size: 11, color: kAccentBright),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          convo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                convo.unread ? FontWeight.w700 : FontWeight.w600,
                            color: kText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo(last.time),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: convo.unread ? kAccentBright : kFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${last.outbound ? 'You: ' : ''}${last.text}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: convo.unread ? kText : kMuted,
                          ),
                        ),
                      ),
                      if (convo.unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: kAccentBright,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (convo.campaign != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      convo.campaign!,
                      style: const TextStyle(fontSize: 10.5, color: kFaint),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationPage extends StatefulWidget {
  final String id;

  const ConversationPage({super.key, required this.id});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class CallPage extends StatefulWidget {
  final String name;
  final String phoneNumber;
  final String initials;

  const CallPage({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.initials,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  bool isMuted = false;
  bool isSpeaker = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  const Text(
                    'End-to-end encrypted call',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: kAccent,
                  child: Text(
                    widget.initials,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.phoneNumber,
                  style: const TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Calling...',
                  style: TextStyle(fontSize: 13, color: Colors.blueAccent),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () => setState(() => isMuted = !isMuted),
                        icon: Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          color: isMuted ? Colors.redAccent : Colors.white,
                          size: 28,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => isSpeaker = !isSpeaker),
                        icon: Icon(
                          isSpeaker ? Icons.volume_up : Icons.volume_down,
                          color: isSpeaker ? kAccentBright : Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationPageState extends State<ConversationPage> {
  final controller = TextEditingController();
  final scroll = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _send(Conversation convo) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (!requireSms(context, convo.channel)) return;
    if (!requireSubscription(context)) return;
    if (!requireProvider(context)) return;

    AppScope.of(context).sendMessage(
      channel: convo.channel,
      address: convo.address,
      name: convo.name,
      text: text,
    );
    controller.clear();
    setState(() {});
  }

  void _makeCall(Conversation convo) {
    if (convo.channel == Channel.sms && convo.address.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallPage(
            name: convo.title,
            phoneNumber: convo.address,
            initials: convo.initials,
          ),
        ),
      );
    } else {
      showToast(context, 'Voice calls are available for phone contacts.');
    }
  }

  Future<void> _copyAddress(Conversation convo) async {
    await Clipboard.setData(ClipboardData(text: convo.address));
    if (!mounted) return;
    showToast(
      context,
      convo.channel == Channel.sms ? 'Number copied.' : 'Email address copied.',
    );
  }

  void _editContact(Conversation convo) {
    final nameCtrl = TextEditingController(text: convo.name);
    final addressCtrl = TextEditingController(text: convo.address);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Client Name',
                hintText: 'Enter new name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(
                labelText: convo.channel == Channel.sms ? 'Phone Number' : 'Email Address',
                hintText: convo.channel == Channel.sms ? 'Enter phone number' : 'Enter email address',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newAddress = addressCtrl.text.trim();

              if (newName.isNotEmpty && newAddress.isNotEmpty) {
                AppScope.of(context)
                    .editConversationContact(convo, newName, newAddress);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteChat(Conversation convo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this entire conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () {
              final state = AppScope.of(context);
              state.deleteConversation(convo);
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(); // Back to messages list
              showToast(context, 'Chat deleted.');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onMessageLongPress(ChatMessage message, Conversation convo) {
    if (!message.outbound) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit message'),
              onTap: () {
                Navigator.of(ctx).pop();
                _editMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.of(ctx).pop();
                showToast(context, 'Message text copied.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kRed),
              title: const Text('Delete message', style: TextStyle(color: kRed)),
              onTap: () {
                AppScope.of(context).deleteMessage(convo, message);
                Navigator.of(ctx).pop();
                showToast(context, 'Message deleted.');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editMessage(ChatMessage message) {
    final editCtrl = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Edit your message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (editCtrl.text.trim().isNotEmpty) {
                AppScope.of(context).editMessage(message, editCtrl.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _ticks(MessageStatus status) {
    switch (status) {
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded, size: 13, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.done_rounded, size: 13, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70);
      case MessageStatus.read:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all_rounded, size: 13, color: Colors.blueAccent),
            SizedBox(width: 2),
            Text('Seen', style: TextStyle(fontSize: 9, color: Colors.white70)),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final convo = state.conversationById(widget.id);
    if (convo == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    if (convo.unread) {
      // Also covers replies that arrive while this chat is open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) state.markRead(convo);
      });
    }

    final messages = convo.messages.reversed.toList();
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar(initials: convo.initials, radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    convo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    convo.channel == Channel.sms
                        ? Contact(name: '', phone: convo.address).prettyPhone
                        : convo.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: kMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Call contact',
            icon: const Icon(Icons.phone_outlined, size: 20),
            onPressed: () => _makeCall(convo),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (v) {
              if (v == 'copy') _copyAddress(convo);
              if (v == 'edit') _editContact(convo);
              if (v == 'delete') _deleteChat(convo);
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'copy', child: Text('Copy contact')),
              PopupMenuItem<String>(value: 'edit', child: Text('Edit contact')),
              PopupMenuItem<String>(value: 'delete', child: Text('Delete chat')),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scroll,
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                final out = m.outbound;
                return Align(
                  alignment: out ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: () => _onMessageLongPress(m, convo),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: out ? kAccent : kSurface,
                        border: out ? null : Border.all(color: kLine),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(out ? 16 : 4),
                          bottomRight: Radius.circular(out ? 4 : 16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.text,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: out ? Colors.white : kText,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (m.isEdited) ...[
                                Text(
                                  'edited · ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: out ? Colors.white60 : kFaint,
                                  ),
                                ),
                              ],
                              Text(
                                formatTime(m.time),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: out ? Colors.white60 : kFaint,
                                ),
                              ),
                              if (out) ...[
                                const SizedBox(width: 4),
                                _ticks(m.status),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: kBg,
              border: Border(top: BorderSide(color: kLine)),
            ),
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach',
                    icon: const Icon(Icons.add_rounded, color: kMuted),
                    onPressed: () => showToast(context, 'Attachments are coming soon.'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: kLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: kLine),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: kAccentBright, width: 1.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: kAccent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _send(convo),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

void showComposeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ComposeSheet(),
  );
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final nameController = TextEditingController();
  final toController = TextEditingController();
  final messageController = TextEditingController();
  Channel channel = Channel.sms;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    toController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _send() {
    final nameInput = nameController.text.trim();
    final to = toController.text.trim();
    final text = messageController.text.trim();
    
    String address;
    if (channel == Channel.sms) {
      final phone = _normalizePhone(to);
      if (phone == null) {
        setState(() => error = 'Enter a valid phone number.');
        return;
      }
      address = phone;
    } else {
      if (!isValidEmail(to)) {
        setState(() => error = 'Enter a valid email address.');
        return;
      }
      address = to.toLowerCase();
    }
    if (text.isEmpty) {
      setState(() => error = 'Write a message first.');
      return;
    }
    if (!requireSms(context, channel)) return;
    if (!requireSubscription(context)) return;
    if (!requireProvider(context)) return;

    final finalName = nameInput.isEmpty ? address : nameInput;

    final state = AppScope.of(context);
    final convo = state.sendMessage(
      channel: channel,
      address: address,
      name: finalName,
      text: text,
    );
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => ConversationPage(id: convo.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New message', style: h1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final c in Channel.values)
                  ChoicePill(
                    label: c.label,
                    icon: c.icon,
                    selected: channel == c,
                    onTap: () => setState(() {
                      channel = c;
                      error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Contact Name (Optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. John Doe',
              ),
            ),
            const SizedBox(height: 14),
            const FieldLabel('To'),
            const SizedBox(height: 8),
            TextField(
              controller: toController,
              keyboardType: channel == Channel.sms
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: channel == Channel.sms
                    ? '+14155550101'
                    : 'name@company.com',
              ),
            ),
            const SizedBox(height: 12),
            const FieldLabel('Message'),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Write your message…'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(fontSize: 12, color: kRed)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _send, child: const Text('Send')),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campaigns
// ---------------------------------------------------------------------------

class CampaignsTab extends StatefulWidget {
  const CampaignsTab({super.key});

  @override
  State<CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends State<CampaignsTab> {
  static const filters = ['All', 'Active', 'Completed'];
  int filter = 0;

  void _openNew() {
    if (!requireSubscription(context)) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewCampaignPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final visible = state.campaigns.where((c) {
      if (filters[filter] == 'Active') return c.isActive;
      if (filters[filter] == 'Completed') return !c.isActive;
      return true;
    }).toList();

    return Column(
      children: [
        PageHeader(
          title: 'Campaigns',
          subtitle: '${state.activeCampaigns} active',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kLeadMarketEnabled) ...[
                RoundIconButton(
                  icon: Icons.people_outline_rounded,
                  tooltip: 'Contacts',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContactsPage()),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              RoundIconButton(
                icon: Icons.add_rounded,
                tooltip: 'New campaign',
                onTap: _openNew,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SegmentTabs(
            labels: filters,
            index: filter,
            onChanged: (i) => setState(() => filter = i),
          ),
        ),
        Expanded(
          child: state.campaigns.isEmpty
              ? EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No campaigns yet',
                  message: 'Create a campaign to message your contacts in bulk.',
                  actionLabel: 'New campaign',
                  onAction: _openNew,
                )
              : visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.filter_list_rounded,
                      title: 'Nothing here',
                      message: 'No campaigns match this filter.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: visible.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CampaignCard(campaign: visible[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class CampaignCard extends StatelessWidget {
  final Campaign campaign;

  const CampaignCard({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    final done = campaign.status == CampaignStatus.completed;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CampaignDetailsPage(campaign: campaign),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: campaign.channel.icon, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rowTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${campaign.channel.label} · '
                      '${formatCount(campaign.recipients)} recipients · '
                      '${longTimeAgo(campaign.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rowSub,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: campaign.status),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: campaign.progress,
              minHeight: 4,
              backgroundColor: kSurfaceHi,
              color: done ? kGreen : kAccentBright,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Stat2('Sent', formatCount(campaign.sent))),
              Expanded(child: _Stat2('Delivered', formatCount(campaign.delivered))),
              Expanded(child: _Stat2('Replies', formatCount(campaign.replies))),
              Expanded(child: _Stat2('Failed', formatCount(campaign.failed))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat2 extends StatelessWidget {
  final String label;
  final String value;

  const _Stat2(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: kText,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(fontSize: 10.5, color: kMuted)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final CampaignStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case CampaignStatus.queued:
        return const Pill('Queued', color: kAmber);
      case CampaignStatus.sending:
        return const Pill('Sending', color: kAccentBright);
      case CampaignStatus.completed:
        return const Pill('Completed', color: kGreen);
    }
  }
}

// ---------------------------------------------------------------------------
// Campaign analytics
// ---------------------------------------------------------------------------

class CampaignDetailsPage extends StatelessWidget {
  final Campaign campaign;

  const CampaignDetailsPage({super.key, required this.campaign});

  String _pct(int part, int whole) =>
      whole == 0 ? '—' : '${(part / whole * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    // Rebuild while the demo delivery simulation updates the numbers.
    AppScope.of(context);

    final c = campaign;
    final isEmail = c.channel == Channel.email;

    // Cumulative series for the engagement chart (shape is illustrative).
    const fa = [0.18, 0.42, 0.68, 0.88, 1.0];
    const fb = [0.08, 0.26, 0.5, 0.78, 1.0];
    final second = isEmail ? c.opened : c.replies;
    final seriesA = [for (final f in fa) c.delivered * f];
    final seriesB = [for (final f in fb) second * f];
    final days = [
      for (var i = 0; i < fa.length; i++)
        formatShortDate(c.createdAt.add(Duration(days: i))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                IconBadge(icon: c.channel.icon, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: h2.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        'Started ${formatDate(c.createdAt)} · '
                        '${formatCount(c.recipients)} recipients',
                        style: rowSub,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(status: c.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(label: 'Sent', value: formatCount(c.sent)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Delivered',
                    value: formatCount(c.delivered),
                    sub: '(${_pct(c.delivered, c.sent)})',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: isEmail
                      ? _MetricTile(
                          label: 'Opened',
                          value: formatCount(c.opened),
                          sub: '(${_pct(c.opened, c.delivered)})',
                        )
                      : _MetricTile(
                          label: 'Failed',
                          value: formatCount(c.failed),
                          sub: '(${_pct(c.failed, c.sent)})',
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Replies',
                    value: formatCount(c.replies),
                    sub: '(${_pct(c.replies, c.delivered)})',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Engagement', style: h2),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const _LegendDot(color: kAccentBright, label: 'Delivered'),
                      const SizedBox(width: 14),
                      _LegendDot(
                        color: kGreen,
                        label: isEmail ? 'Opened' : 'Replies',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EngagementChart(a: seriesA, b: seriesB, labels: days),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('Message', style: h2),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.subject.isNotEmpty) ...[
                    const FieldLabel('Subject'),
                    const SizedBox(height: 4),
                    Text(c.subject, style: const TextStyle(fontSize: 13, color: kText)),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    c.message,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: kText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;

  const _MetricTile({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: rowSub),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kText,
                letterSpacing: -0.6,
                height: 1,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub!, style: rowSub),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: kMuted)),
      ],
    );
  }
}

class _EngagementChart extends StatelessWidget {
  final List<double> a;
  final List<double> b;
  final List<String> labels;

  const _EngagementChart({
    required this.a,
    required this.b,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final top = max(1.0, max(a.last, b.last));
    final yLabels = [
      for (var i = 3; i >= 0; i--) formatCount((top * i / 3).round()),
    ];

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in yLabels)
                      Text(l, style: const TextStyle(fontSize: 10, color: kFaint)),
                  ],
                ),
              ),
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _ChartPainter(a: a, b: b, maxV: top),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in labels)
                Text(l, style: const TextStyle(fontSize: 10, color: kFaint)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> a;
  final List<double> b;
  final double maxV;

  const _ChartPainter({required this.a, required this.b, required this.maxV});

  Path _line(List<double> v, Size size) {
    final path = Path();
    final dx = size.width / (v.length - 1);
    Offset p(int i) => Offset(i * dx, size.height - (v[i] / maxV) * size.height);
    path.moveTo(p(0).dx, p(0).dy);
    for (var i = 1; i < v.length; i++) {
      final prev = p(i - 1);
      final cur = p(i);
      final mid = (prev.dx + cur.dx) / 2;
      path.cubicTo(mid, prev.dy, mid, cur.dy, cur.dx, cur.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = kLine
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final lineA = _line(a, size);
    final fill = Path.from(lineA)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kAccentBright.withValues(alpha: 0.22),
            kAccentBright.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      lineA,
      Paint()
        ..color = kAccentBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      _line(b, size),
      Paint()
        ..color = kGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.a != a || old.b != b || old.maxV != maxV;
}

// ---------------------------------------------------------------------------
// New campaign: details -> select contacts -> review & send
// ---------------------------------------------------------------------------

class NewCampaignPage extends StatefulWidget {
  const NewCampaignPage({super.key});

  @override
  State<NewCampaignPage> createState() => _NewCampaignPageState();
}

class _NewCampaignPageState extends State<NewCampaignPage> {
  static const int maxChars = 500;

  final nameController = TextEditingController();
  final fromNameController = TextEditingController();
  final fromEmailController = TextEditingController();
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  Channel channel = Channel.sms;
  bool _prefilled = false;

  int get segments =>
      channel == Channel.sms ? smsSegments(messageController.text) : 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final provider = AppScope.of(context).provider;
    if (provider != null && provider.emailDomain.isNotEmpty) {
      fromEmailController.text = 'hello@${provider.emailDomain}';
    }
    final name = AppScope.of(context).userName;
    if (name.isNotEmpty) fromNameController.text = name;
  }

  @override
  void dispose() {
    nameController.dispose();
    fromNameController.dispose();
    fromEmailController.dispose();
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _addOptOut() {
    final line = channel == Channel.sms
        ? 'Reply STOP to opt out.'
        : 'Reply UNSUBSCRIBE to stop receiving these emails.';
    final text = messageController.text.trimRight();
    final upper = text.toUpperCase();
    if (upper.contains('STOP') || upper.contains('UNSUBSCRIBE')) {
      showToast(context, 'Your message already has an opt-out line.');
      return;
    }
    messageController.text = text.isEmpty ? line : '$text\n$line';
    messageController.selection = TextSelection.collapsed(
      offset: messageController.text.length,
    );
    setState(() {});
  }

  Future<void> _openTemplates() async {
    final picked = await Navigator.of(context).push<MessageTemplate>(
      MaterialPageRoute(builder: (_) => TemplatesPage(initial: channel)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      channel = picked.channel;
      messageController.text = picked.body;
      if (channel == Channel.email) subjectController.text = picked.subject;
      if (nameController.text.trim().isEmpty) nameController.text = picked.name;
    });
  }

  bool get _canContinue {
    if (nameController.text.trim().isEmpty ||
        messageController.text.trim().isEmpty) {
      return false;
    }
    if (channel == Channel.email) {
      return subjectController.text.trim().isNotEmpty &&
          fromNameController.text.trim().isNotEmpty &&
          isValidEmail(fromEmailController.text);
    }
    return true;
  }

  void _next() {
    final draft = CampaignDraft(
      name: nameController.text.trim(),
      subject: subjectController.text.trim(),
      fromName: fromNameController.text.trim(),
      fromEmail: fromEmailController.text.trim(),
      message: messageController.text.trim(),
      channel: channel,
      segments: segments,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SelectContactsPage(draft: draft)),
    );
  }

  Widget _gap([double h = 14]) => SizedBox(height: h);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final recipients = state.recipientsFor(channel);
    final length = messageController.text.runes.length;
    final isEmail = channel == Channel.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New campaign'),
        actions: [
          if (isEmail)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: Pill('Email', color: kAccentBright)),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text('Campaign details', style: h2),
            _gap(12),
            const FieldLabel('Campaign name'),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: isEmail ? 'e.g. Product launch' : 'e.g. Website outreach',
              ),
            ),
            _gap(),
            const FieldLabel('Message type'),
            const SizedBox(height: 6),
            SegmentTabs(
              labels: const ['SMS', 'Email'],
              index: isEmail ? 1 : 0,
              onChanged: (i) => setState(
                () => channel = i == 0 ? Channel.sms : Channel.email,
              ),
            ),
            if (isEmail) ...[
              _gap(),
              const FieldLabel('From name'),
              const SizedBox(height: 6),
              TextField(
                controller: fromNameController,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. LeadText Team'),
              ),
              _gap(),
              const FieldLabel('From email'),
              const SizedBox(height: 6),
              TextField(
                controller: fromEmailController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'hello@yourdomain.com'),
              ),
              _gap(),
              const FieldLabel('Subject'),
              const SizedBox(height: 6),
              TextField(
                controller: subjectController,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Email subject'),
              ),
            ],
            _gap(),
            Row(
              children: [
                const FieldLabel('Message'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openTemplates,
                  icon: const Icon(Icons.auto_awesome_outlined, size: 15),
                  label: const Text('Templates'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: messageController,
              onChanged: (_) => setState(() {}),
              minLines: 5,
              maxLines: 9,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 13, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Hi {{name}}, …',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _addOptOut,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Add opt-out line'),
                ),
                const Spacer(),
                Text(
                  isEmail
                      ? '$length chars'
                      : '$length/$maxChars · $segments '
                          '${segments == 1 ? 'segment' : 'segments'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: !isEmail && length > maxChars ? kAmber : kMuted,
                  ),
                ),
              ],
            ),
            _gap(10),
            const FieldLabel('Add contacts'),
            const SizedBox(height: 6),
            AppCard(
              onTap: _canContinue ? _next : null,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const IconBadge(icon: Icons.people_alt_outlined, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recipients > 0
                          ? 'Choose from your contacts '
                              '(${formatCount(recipients)} with a '
                              '${isEmail ? 'email' : 'phone number'})'
                          : 'Choose from your contacts or import',
                      style: rowSub,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: kFaint),
                ],
              ),
            ),
            _gap(20),
            FilledButton(
              onPressed: _canContinue ? _next : null,
              child: const Text('Next'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Only message people who have agreed to hear from you, and '
              'honour every opt-out.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: kFaint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Templates (full screen) ----

class TemplatesPage extends StatefulWidget {
  final Channel initial;

  const TemplatesPage({super.key, required this.initial});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  late Channel channel = widget.initial;
  MessageTemplate? selected;

  @override
  Widget build(BuildContext context) {
    final items = kTemplates.where((t) => t.channel == channel).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: SegmentTabs(
                labels: const ['SMS', 'Email'],
                index: channel == Channel.sms ? 0 : 1,
                onChanged: (i) => setState(() {
                  channel = i == 0 ? Channel.sms : Channel.email;
                  selected = null;
                }),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final t = items[i];
                  final isSel = identical(selected, t);
                  return Material(
                    color: kSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSel ? kAccentBright : kLine,
                        width: isSel ? 1.4 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() => selected = t),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            IconBadge(icon: t.icon, size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.name, style: rowTitle),
                                  const SizedBox(height: 2),
                                  Text(t.blurb, style: rowSub),
                                ],
                              ),
                            ),
                            Icon(
                              isSel
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: isSel ? kAccentBright : kFaint,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: kBg,
                border: Border(top: BorderSide(color: kLine)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.of(context).pop(selected),
                  child: const Text('Create from template'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Select contacts ----

class SelectContactsPage extends StatefulWidget {
  final CampaignDraft draft;

  const SelectContactsPage({super.key, required this.draft});

  @override
  State<SelectContactsPage> createState() => _SelectContactsPageState();
}

class _SelectContactsPageState extends State<SelectContactsPage> {
  final searchController = TextEditingController();
  final Set<String> selectedKeys = {};
  bool selectIndividual = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _next() {
    final state = AppScope.of(context);
    
    // The exact list of addresses the campaign will be sent to.
    final addrs = <String>{};
    for (final c in state.contacts) {
      final addr = widget.draft.channel == Channel.sms ? c.phone : c.email;
      if (addr.isEmpty) continue;
      final include = selectIndividual
          ? selectedKeys.contains(c.key)
          : (selectedKeys.contains('__all__') ||
              (c.group.isNotEmpty && selectedKeys.contains(c.group)));
      if (include) addrs.add(addr);
    }
    final count = addrs.length;

    if (count == 0) {
      showToast(
        context,
        'None of the selected contacts have a '
        '${widget.draft.channel == Channel.sms ? 'phone number' : 'email address'}.',
      );
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewSendPage(
          draft: widget.draft,
          recipients: count,
          addresses: addrs.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ch = widget.draft.channel;
    final query = searchController.text.trim().toLowerCase();

    final matchingContacts = state.contacts.where((c) {
      final hasAddr = ch == Channel.sms ? c.phone.isNotEmpty : c.email.isNotEmpty;
      if (!hasAddr) return false;
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) || c.detail.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select contacts'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentTabs(
                      labels: const ['Groups/Lists', 'Individual Contacts'],
                      index: selectIndividual ? 1 : 0,
                      onChanged: (i) => setState(() {
                        selectIndividual = i == 1;
                        selectedKeys.clear();
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: selectIndividual ? 'Search individual contacts...' : 'Search groups or lists...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                ),
              ),
            ),
            if (selectIndividual && matchingContacts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          final allKeys = matchingContacts.map((c) => c.key).toSet();
                          if (selectedKeys.containsAll(allKeys)) {
                            selectedKeys.removeAll(allKeys);
                          } else {
                            selectedKeys.addAll(allKeys);
                          }
                        });
                      },
                      icon: Icon(
                        selectedKeys.containsAll(matchingContacts.map((c) => c.key))
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 20,
                      ),
                      label: Text(
                        selectedKeys.containsAll(matchingContacts.map((c) => c.key))
                            ? 'Deselect All'
                            : 'Select All (${matchingContacts.length})',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: state.contacts.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No contacts yet',
                      message: 'Add contacts first, then pick who gets this campaign.',
                      actionLabel: 'Add contacts',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ContactsPage()),
                      ),
                    )
                  : selectIndividual
                      ? (matchingContacts.isEmpty
                          ? const EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matches',
                              message: 'Try a different search query.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                              itemCount: matchingContacts.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, i) {
                                final contact = matchingContacts[i];
                                final on = selectedKeys.contains(contact.key);
                                return InkWell(
                                  onTap: () => setState(() {
                                    if (!selectedKeys.add(contact.key)) selectedKeys.remove(contact.key);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: on,
                                          onChanged: (_) => setState(() {
                                            if (!selectedKeys.add(contact.key)) selectedKeys.remove(contact.key);
                                          }),
                                          activeColor: kAccent,
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Avatar(initials: contact.initials, radius: 16),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(contact.displayName, style: rowTitle),
                                              Text(contact.detail, style: rowSub),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                          itemCount: 1 + state.groupNames(lists: false).length + state.groupNames(lists: true).length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, i) {
                            final allGroups = [
                              (id: '__all__', title: 'All contacts', count: state.countFor(null, ch)),
                              for (final g in state.groupNames(lists: false))
                                (id: g, title: g, count: state.countFor(g, ch)),
                              for (final g in state.groupNames(lists: true))
                                (id: g, title: g, count: state.countFor(g, ch)),
                            ];
                            
                            final visible = allGroups
                                .where((r) => query.isEmpty || r.title.toLowerCase().contains(query))
                                .toList();

                            if (i >= visible.length) return const SizedBox.shrink();
                            final r = visible[i];
                            final on = selectedKeys.contains(r.id);

                            return InkWell(
                              onTap: () => setState(() {
                                if (!selectedKeys.add(r.id)) selectedKeys.remove(r.id);
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: on,
                                      onChanged: (_) => setState(() {
                                        if (!selectedKeys.add(r.id)) selectedKeys.remove(r.id);
                                      }),
                                      activeColor: kAccent,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r.title, style: rowTitle),
                                          Text('${formatCount(r.count)} contacts', style: rowSub),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: kBg,
                border: Border(top: BorderSide(color: kLine)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selectedKeys.isEmpty ? null : _next,
                  child: Text(
                    selectedKeys.isEmpty
                        ? 'Next'
                        : 'Next (${selectedKeys.length} selected)',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Review & send ----

class ReviewSendPage extends StatelessWidget {
  final CampaignDraft draft;
  final int recipients;
  final List<String> addresses;

  const ReviewSendPage({
    super.key,
    required this.draft,
    required this.recipients,
    required this.addresses,
  });

  Future<void> _confirmAndSend(BuildContext context) async {
    if (!requireSms(context, draft.channel)) return;
    if (!requireSubscription(context)) return;
    if (!requireProvider(context)) return;

    final state = AppScope.of(context);
    final isSms = draft.channel == Channel.sms;
    final estimate = recipients * draft.segments * smsPricePerSegment;
    final short = isSms && estimate > state.telnyxBalance;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kLine),
        ),
        title: const Text('Send campaign?', style: TextStyle(fontSize: 17)),
        content: Text(
          'This will ${isSms ? 'text' : 'email'} '
          '${formatCount(recipients)} contacts through your Telnyx account.'
          '${isSms ? ' Estimated Telnyx cost: ${formatMoney(estimate)}.' : ''}'
          '${short ? '\n\nHeads up: your Telnyx balance is ${formatMoney(state.telnyxBalance)}, which may not cover the whole campaign.' : ''}',
          style: bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final campaign = Campaign(
      id: _uuid(),
      name: draft.name,
      message: draft.message,
      subject: draft.subject,
      channel: draft.channel,
      recipients: recipients,
      segments: draft.segments,
      createdAt: DateTime.now(),
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    state.setTab(kTabCampaigns);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '"${campaign.name}" is sending to ${formatCount(recipients)} contacts.',
          ),
        ),
      );

    final error = await state.launchCampaign(campaign, addresses);
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Campaign failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isSms = draft.channel == Channel.sms;
    final estimate = recipients * draft.segments * smsPricePerSegment;
    final connected = state.provider != null;
    final short = connected && isSms && estimate > state.telnyxBalance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & send'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text('Campaign summary', style: h2),
            const SizedBox(height: 10),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        IconBadge(icon: draft.channel.icon, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(draft.name, style: rowTitle),
                              const SizedBox(height: 2),
                              Text(draft.channel.label, style: rowSub),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  SummaryRow(label: 'Recipients', value: formatCount(recipients)),
                  if (isSms) ...[
                    const Divider(),
                    SummaryRow(label: 'Segments per contact', value: '${draft.segments}'),
                    const Divider(),
                    SummaryRow(
                      label: 'Estimated Telnyx cost',
                      value: formatMoney(estimate),
                    ),
                    if (connected) ...[
                      const Divider(),
                      SummaryRow(
                        label: 'Your Telnyx balance',
                        value: formatMoney(state.telnyxBalance),
                        valueColor: short ? kAmber : null,
                      ),
                    ],
                  ] else ...[
                    const Divider(),
                    SummaryRow(
                      label: 'From',
                      value: '${draft.fromName} <${draft.fromEmail}>',
                    ),
                  ],
                  const Divider(),
                  const SummaryRow(label: 'Billed by', value: 'Your Telnyx account'),
                ],
              ),
            ),
            if (!connected) ...[
              const SizedBox(height: 10),
              const Text(
                'Telnyx is not connected yet. Connect it in More so messages '
                'can be delivered.',
                style: TextStyle(fontSize: 12, color: kAmber, height: 1.4),
              ),
            ] else if (short) ...[
              const SizedBox(height: 10),
              const Text(
                'Your Telnyx balance may not cover this whole campaign. '
                'Add funds in Telnyx before sending.',
                style: TextStyle(fontSize: 12, color: kAmber, height: 1.4),
              ),
            ],
            const SizedBox(height: 22),
            const Text('Message preview', style: h2),
            const SizedBox(height: 10),
            AppCard(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (draft.subject.isNotEmpty) ...[
                      const FieldLabel('Subject'),
                      const SizedBox(height: 4),
                      Text(
                        draft.subject,
                        style: const TextStyle(fontSize: 13, color: kText),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      draft.message,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: kText),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        showToast(context, 'Scheduling is coming soon.'),
                    child: const Text('Schedule'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _confirmAndSend(context),
                    child: const Text('Send now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contacts
// ---------------------------------------------------------------------------

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _openPaste() async {
    final state = AppScope.of(context);
    final added = await Navigator.of(context).push<List<Contact>>(
      MaterialPageRoute(
        builder: (_) => PasteContactsPage(
          existingKeys: state.contacts.map((c) => c.key).toSet(),
        ),
      ),
    );
    if (added == null || added.isEmpty) return;
    final tagged = [
      for (final c in added)
        Contact(
          name: c.name,
          phone: c.phone,
          email: c.email,
          group: 'Pasted contacts',
        ),
    ];
    final count = state.addContacts(tagged);
    if (!mounted) return;
    showToast(
      context,
      '${formatCount(count)} ${count == 1 ? 'contact' : 'contacts'} saved',
    );
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add contacts', style: h1),
              const SizedBox(height: 4),
              const Text('Choose how to bring contacts in.', style: bodyMuted),
              const SizedBox(height: 14),
              _OptionTile(
                icon: Icons.content_paste_rounded,
                title: 'Paste contacts',
                subtitle: 'Phone numbers or emails, hundreds at once',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openPaste();
                },
              ),
              const SizedBox(height: 10),
              _OptionTile(
                icon: Icons.upload_file_rounded,
                title: 'Import CSV',
                subtitle: 'Coming soon',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showToast(context, 'CSV import is coming next.');
                },
              ),
              const SizedBox(height: 10),
              _OptionTile(
                icon: Icons.table_chart_outlined,
                title: 'Google Sheets',
                subtitle: 'Coming soon',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showToast(context, 'Google Sheets sync is coming next.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final query = searchController.text.trim().toLowerCase();
    final digitsQuery = query.replaceAll(RegExp(r'\D'), '');
    final filtered = state.contacts.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.email.toLowerCase().contains(query) ||
          (digitsQuery.isNotEmpty && c.phone.contains(digitsQuery));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: RoundIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Add contacts',
              onTap: _showAddSheet,
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search name, number or email',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17),
                          onPressed: () {
                            searchController.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${formatCount(filtered.length)} '
                  '${filtered.length == 1 ? 'contact' : 'contacts'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: state.contacts.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No contacts yet',
                      message: 'Paste a list of numbers or emails and save them in one tap.',
                      actionLabel: 'Add contacts',
                      onAction: _showAddSheet,
                    )
                  : filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matches',
                          message: 'Try a different name, number or email.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final contact = filtered[index];
                            return Dismissible(
                              key: ValueKey(contact.key),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) {
                                state.removeContact(contact);
                                showToast(context, 'Contact removed');
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: kRed.withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: kRed,
                                ),
                              ),
                              child: _ContactRow(contact: contact),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;

  const _ContactRow({required this.contact});

  void _openChat(BuildContext context) {
    final state = AppScope.of(context);
    final address = contact.key;
    if (address.isEmpty) return;

    final channel = contact.phone.isNotEmpty ? Channel.sms : Channel.email;
    
    Conversation? convo;
    for (final c in state.conversations) {
      if (c.address == address && c.channel == channel) {
        convo = c;
        break;
      }
    }

    if (convo == null) {
      convo = Conversation(
        id: 'c${DateTime.now().microsecondsSinceEpoch}',
        name: contact.name,
        address: address,
        channel: channel,
        messages: [],
      );
      state.conversations.insert(0, convo);
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConversationPage(id: convo!.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openChat(context),
      child: Container(
        color: kBg,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            Avatar(initials: contact.initials, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rowTitle,
                  ),
                  if (contact.name.isNotEmpty)
                    Text(contact.detail, style: rowSub),
                ],
              ),
            ),
            Icon(
              contact.phone.isNotEmpty ? Icons.sms_outlined : Icons.mail_outline_rounded,
              size: 16,
              color: kFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconBadge(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: rowTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: rowSub),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: kFaint),
        ],
      ),
    );
  }
}

class PasteContactsPage extends StatefulWidget {
  final Set<String> existingKeys;

  const PasteContactsPage({super.key, required this.existingKeys});

  @override
  State<PasteContactsPage> createState() => _PasteContactsPageState();
}

class _PasteContactsPageState extends State<PasteContactsPage> {
  final controller = TextEditingController();
  ParseResult result = ParseResult.empty;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _reparse() {
    setState(() {
      result = parseContacts(controller.text, existing: widget.existingKeys);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) showToast(context, 'Your clipboard is empty.');
      return;
    }
    controller.text =
        controller.text.isEmpty ? text : '${controller.text}\n$text';
    _reparse();
  }

  String get _detailText {
    if (controller.text.trim().isEmpty) {
      return 'Entries are cleaned, de-duplicated and validated automatically.';
    }
    final parts = <String>[
      if (result.duplicates > 0)
        '${formatCount(result.duplicates)} '
            '${result.duplicates == 1 ? 'duplicate' : 'duplicates'} skipped',
      if (result.invalid > 0) '${formatCount(result.invalid)} invalid skipped',
    ];
    return parts.isEmpty ? 'All entries look good.' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final count = result.contacts.length;
    final preview = result.contacts.take(4).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paste contacts'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const Text(
              'Paste phone numbers or emails, with names if you have them. '
              'One per line, or separated by commas.',
              style: bodyMuted,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              onChanged: (_) => _reparse(),
              minLines: 8,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 13, height: 1.5),
              decoration: const InputDecoration(
                hintText: '+14155550101\n'
                    'John - +14155550102\n'
                    'Mary, mary@company.com',
                hintMaxLines: 4,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 17),
                  label: const Text('Paste from clipboard'),
                ),
                const Spacer(),
                if (controller.text.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      controller.clear();
                      _reparse();
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const IconBadge(icon: Icons.people_alt_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${formatCount(count)} '
                                '${count == 1 ? 'contact' : 'contacts'} found',
                                style: h2,
                              ),
                              const SizedBox(height: 2),
                              Text(_detailText, style: rowSub),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final contact in preview) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.name.isEmpty ? '—' : contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: kText,
                              ),
                            ),
                          ),
                          Text(
                            contact.detail,
                            style: const TextStyle(fontSize: 12, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (count > preview.length) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        '+ ${formatCount(count - preview.length)} more',
                        style: const TextStyle(fontSize: 11.5, color: kMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  count == 0 ? null : () => Navigator.of(context).pop(result.contacts),
              child: Text(
                count == 0
                    ? 'Save contacts'
                    : 'Save ${formatCount(count)} '
                        '${count == 1 ? 'contact' : 'contacts'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LeadMarket: demo data
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Demo inventory (clearly fake: example.com domains, fictional numbers).
// The live app reads real inventory from Google Sheets through the backend.
// ---------------------------------------------------------------------------

const List<String> _kExtraCategories = [
  'Landscaping',
  'Dental Clinics',
  'Law Firms',
  'Restaurants',
];

const Map<String, Map<String, List<String>>> kLocations = {
  'USA': {
    'Texas': ['Austin', 'Dallas', 'Houston'],
    'Colorado': ['Denver', 'Boulder'],
    'Florida': ['Miami', 'Orlando', 'Tampa'],
    'Washington': ['Seattle', 'Spokane'],
    'Illinois': ['Chicago', 'Springfield'],
    'California': ['Los Angeles', 'San Diego', 'San Francisco'],
  },
  'UK': {
    'England': ['London', 'Manchester', 'Leeds'],
    'Scotland': ['Glasgow', 'Edinburgh'],
    'Wales': ['Cardiff', 'Swansea'],
  },
  'Canada': {
    'Ontario': ['Toronto', 'Ottawa'],
    'British Columbia': ['Vancouver', 'Victoria'],
    'Alberta': ['Calgary', 'Edmonton'],
    'Quebec': ['Montreal', 'Quebec City'],
  },
};

const Map<String, List<String>> _demoAreaCodes = {
  'USA': ['415', '212', '512', '303', '305', '206'],
  'Canada': ['416', '604', '403', '514', '613'],
};

const Map<String, List<String>> _categoryNouns = {
  'Painters': ['Painting', 'Painters', 'Paint Pros'],
  'Plumbers': ['Plumbing', 'Plumbers', 'Pipe Works'],
  'Electricians': ['Electric', 'Electrical', 'Wiring Co'],
  'Flooring Contractors': ['Flooring', 'Floors', 'Tile and Floor'],
  'Roofers': ['Roofing', 'Roofers', 'Roof Works'],
  'HVAC Contractors': ['HVAC', 'Heating and Air', 'Climate Control'],
  'Cleaning Services': ['Cleaning', 'Cleaners', 'Maid Service'],
  'Real Estate': ['Realty', 'Properties', 'Estates'],
  'Construction': ['Construction', 'Builders', 'Contracting'],
  'Landscaping': ['Landscaping', 'Lawn Care'],
  'Dental Clinics': ['Dental', 'Dentistry'],
  'Law Firms': ['Law', 'Legal'],
  'Restaurants': ['Kitchen', 'Grill', 'Bistro'],
};

const List<String> _companyPrefixes = [
  'Bright', 'Summit', 'Northwind', 'Bluepeak', 'Harbor',
  'Cedar', 'Ironwood', 'Lumen', 'Pioneer', 'Oakline',
  'Redwood', 'Stonebridge', 'Evergreen', 'Atlas', 'Keystone',
];
const List<String> _firstNames = [
  'Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey',
  'Riley', 'Jamie', 'Avery', 'Quinn', 'Drew',
];
const List<String> _lastNames = [
  'Hughes', 'Patel', 'Nguyen', 'Okafor', 'Reed',
  'Silva', 'Brooks', 'Khan', 'Ellis', 'Moore',
];
const List<String> _jobTitles = [
  'Owner', 'Founder', 'Managing Director',
  'Operations Manager', 'General Manager', 'CEO',
];

T _pick<T>(Random r, List<T> list) => list[r.nextInt(list.length)];

/// About 6% of leads repeat an earlier business (same name and city) so the
/// "Exclude duplicate businesses" filter has something to do. About 70% of
/// leads have both a phone and an email; the rest have only one of them.
List<Lead> generateDemoInventory({int count = 4000, int seed = 7}) {
  final rnd = Random(seed);
  final now = DateTime.now();
  const countries = ['USA', 'USA', 'USA', 'UK', 'Canada'];
  final leads = <Lead>[];

  for (var i = 0; i < count; i++) {
    final base = (i > 30 && rnd.nextDouble() < 0.06)
        ? leads[rnd.nextInt(leads.length)]
        : null;

    final country = base?.country ?? _pick(rnd, countries);
    final states = kLocations[country]!;
    final stateName = base?.state ?? _pick(rnd, states.keys.toList());
    final city = base?.city ?? _pick(rnd, states[stateName]!);
    final category = base?.category ??
        _pick(
          rnd,
          rnd.nextDouble() < 0.85 ? kMainCategories : _kExtraCategories,
        );
    final company = base?.company ??
        '${_pick(rnd, _companyPrefixes)} ${_pick(rnd, _categoryNouns[category]!)}';

    var hasPhone = rnd.nextDouble() < 0.88;
    final hasEmail = rnd.nextDouble() < 0.78;
    if (!hasPhone && !hasEmail) hasPhone = true;
    final hasWebsite = rnd.nextDouble() < 0.7;

    final first = _pick(rnd, _firstNames);
    final last = _pick(rnd, _lastNames);
    final slug =
        '${company.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}${i + 1}';

    var phone = '';
    if (hasPhone) {
      if (country == 'UK') {
        phone = '+44207${1000000 + i}';
      } else {
        final area = _pick(rnd, _demoAreaCodes[country]!);
        phone = '+1${area}555${i.toString().padLeft(4, '0')}';
      }
    }

    leads.add(
      Lead(
        id: 'LD-${(i + 1).toString().padLeft(5, '0')}',
    company: company,
    contactName: '$first $last',
    jobTitle: _pick(rnd, _jobTitles) ?? 'Founder',
    phone: phone,
    email: hasEmail ? '${first.toLowerCase()}.${last.toLowerCase()}@$slug.example.com' : '',
    website: hasWebsite ? 'https://$slug.example.com' : '',
    country: country ?? 'USA',
    state: stateName ?? 'TX',
    city: city ?? 'Austin',
    category: category ?? 'Technology',
    dateAdded: now.subtract(
      Duration(days: rnd.nextInt(120), hours: rnd.nextInt(24)),
    ),
    phoneVerified: hasPhone && rnd.nextDouble() < 0.6,
    emailVerified: hasEmail && rnd.nextDouble() < 0.6,
  ), // Lead
    );
  }
  return leads;
}

/// Built once, on first use.
final List<Lead> kLeadInventory = generateDemoInventory();

/// Price in LeadCoins for [quantity] leads (1 LeadCoin = $1), rounded up.
int leadCoinsFor(ContactType type, int quantity) =>
    quantity <= 0 ? 0 : max(1, (quantity * type.pricePer1000 / 1000).ceil());

String maskPhone(String phone) {
  if (phone.length < 8) return phone;
  return '${phone.substring(0, phone.length - 7)} ••• '
      '${phone.substring(phone.length - 4)}';
}

String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at < 2) return email;
  return '${email[0]}•••${email.substring(at)}';
}

Future<void> importOrder(BuildContext context, PurchaseOrder order) async {
  final added = AppScope.of(context).importOrderToContacts(order);
  showToast(
    context,
    added == 0
        ? 'These leads are already in Contacts.'
        : '${formatCount(added)} contacts added.',
  );
}

String orderImportLabel(PurchaseOrder order) =>
    'Import ${formatCount(order.leads.length)} leads to Contacts';

// ---------------------------------------------------------------------------
// LeadMarket
// ---------------------------------------------------------------------------

const String _anyCountry = 'Any country';
const String _anyState = 'Any state / region';
const String _anyCity = 'Any city';

class LeadMarketTab extends StatefulWidget {
  const LeadMarketTab({super.key});

  @override
  State<LeadMarketTab> createState() => _LeadMarketTabState();
}

class _LeadMarketTabState extends State<LeadMarketTab> {
  final searchController = TextEditingController();
  final scroll = ScrollController();
  final resultsKey = GlobalKey();

  String category = kAllCategories;
  ContactType type = ContactType.phone;
  String country = '';
  String stateName = '';
  String city = '';
  bool website = false;
  bool verifiedEmail = false;
  bool verifiedPhone = false;
  bool excludePurchased = true;
  bool excludeDuplicates = true;
  LeadSort sort = LeadSort.newest;

  LeadFilters? applied;
  List<Lead>? results;
  bool searching = false;
  bool buying = false;

  @override
  void dispose() {
    searchController.dispose();
    scroll.dispose();
    super.dispose();
  }

  LeadFilters _filters() => LeadFilters(
        search: searchController.text,
        category: category,
        type: type,
        country: country,
        state: stateName,
        city: city,
        website: website,
        verifiedEmail: verifiedEmail,
        verifiedPhone: verifiedPhone,
        excludePurchased: excludePurchased,
        excludeDuplicates: excludeDuplicates,
        sort: sort,
      );

  void _setType(ContactType t) {
    setState(() {
      type = t;
      // A verified filter only makes sense for a field the buyer receives.
      if (!t.needsEmail) verifiedEmail = false;
      if (!t.needsPhone) verifiedPhone = false;
    });
  }

  Future<void> _find({bool scrollToResults = true}) async {
    FocusScope.of(context).unfocus();
    final state = AppScope.of(context);
    final f = _filters();
    setState(() => searching = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final found = state.searchLeads(f);
    setState(() {
      applied = f;
      results = found;
      searching = false;
    });
    if (!scrollToResults) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = resultsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clear() {
    searchController.clear();
    setState(() {
      category = kAllCategories;
      type = ContactType.phone;
      country = '';
      stateName = '';
      city = '';
      website = false;
      verifiedEmail = false;
      verifiedPhone = false;
      excludePurchased = true;
      excludeDuplicates = true;
      sort = LeadSort.newest;
      applied = null;
      results = null;
    });
  }

  Future<void> _openBuy() async {
    final f = applied;
    final list = results;
    if (f == null || list == null || list.isEmpty || buying) return;

    final qty = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BuySheet(type: f.type, available: list.length),
    );
    if (qty == null || !mounted) return;

    final state = AppScope.of(context);
    setState(() => buying = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final order = state.purchase(
      type: f.type,
      summary: f.summary,
      leads: list.take(qty).toList(),
      orderId: 'LT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
    );
    setState(() => buying = false);
    if (order == null) {
      showToast(context, 'Not enough LeadCoins. You were not charged.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PurchaseSuccessPage(order: order)),
    );
    if (mounted && results != null) _find(scrollToResults: false);
  }

  Widget _head(String title, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: h2),
            if (sub != null) ...[
              const SizedBox(height: 3),
              Text(sub, style: bodyMuted),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final orders = state.orders;
    final totalLeads = orders.fold<int>(0, (s, o) => s + o.leads.length);

    final stateOptions = [
      _anyState,
      if (country.isNotEmpty) ...kLocations[country]!.keys,
    ];
    final cityOptions = [
      _anyCity,
      if (country.isNotEmpty && stateName.isNotEmpty)
        ...kLocations[country]![stateName]!,
    ];

    return Column(
      children: [
        PageHeader(
          title: 'LeadMarket',
          subtitle: 'Find business leads that match your target customers.',
          trailing: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletPage()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: kLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.toll_rounded, size: 15, color: kAccentBright),
                  const SizedBox(width: 6),
                  Text(
                    formatCount(state.coins),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyLeadsPage()),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const IconBadge(icon: Icons.inventory_2_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('My leads', style: rowTitle),
                            const SizedBox(height: 2),
                            Text(
                              orders.isEmpty
                                  ? 'Your purchased leads will appear here'
                                  : '${orders.length} '
                                      '${orders.length == 1 ? 'purchase' : 'purchases'}'
                                      ' · ${formatCount(totalLeads)} leads',
                              style: rowSub,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: kFaint),
                    ],
                  ),
                ),

                // ---- Search ----
                _head('Search'),
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _find(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search business name, keyword or industry',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 17),
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),

                // ---- Business category ----
                _head('Business category'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in [
                      kAllCategories,
                      ...kMainCategories,
                      kOtherCategories,
                    ])
                      ChoicePill(
                        label: c,
                        selected: category == c,
                        onTap: () => setState(() => category = c),
                      ),
                  ],
                ),

                // ---- Contact information ----
                _head(
                  'Contact information',
                  'Choose which contact details your leads must have.',
                ),
                for (final t in ContactType.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ContactTypeCard(
                      type: t,
                      selected: type == t,
                      onTap: () => _setType(t),
                    ),
                  ),

                // ---- Location ----
                _head('Location'),
                const FieldLabel('Country'),
                const SizedBox(height: 6),
                _FilterPill(
                  value: country.isEmpty ? _anyCountry : country,
                  allValue: _anyCountry,
                  options: [_anyCountry, ...kLocations.keys],
                  onSelected: (v) => setState(() {
                    country = v == _anyCountry ? '' : v;
                    stateName = '';
                    city = '';
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('State / Region'),
                          const SizedBox(height: 6),
                          _FilterPill(
                            value: stateName.isEmpty ? _anyState : stateName,
                            allValue: _anyState,
                            options: stateOptions,
                            enabled: country.isNotEmpty,
                            onSelected: (v) => setState(() {
                              stateName = v == _anyState ? '' : v;
                              city = '';
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('City'),
                          const SizedBox(height: 6),
                          _FilterPill(
                            value: city.isEmpty ? _anyCity : city,
                            allValue: _anyCity,
                            options: cityOptions,
                            enabled: stateName.isNotEmpty,
                            onSelected: (v) =>
                                setState(() => city = v == _anyCity ? '' : v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ---- Additional filters ----
                _head('Additional filters'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _FilterSwitch(
                        title: 'Website available',
                        value: website,
                        onChanged: (v) => setState(() => website = v),
                      ),
                      const Divider(),
                      _FilterSwitch(
                        title: 'Verified email only',
                        note: type.needsEmail ? null : 'Not part of a phone-only list',
                        value: verifiedEmail,
                        onChanged: type.needsEmail
                            ? (v) => setState(() => verifiedEmail = v)
                            : null,
                      ),
                      const Divider(),
                      _FilterSwitch(
                        title: 'Verified phone only',
                        note: type.needsPhone ? null : 'Not part of an email-only list',
                        value: verifiedPhone,
                        onChanged: type.needsPhone
                            ? (v) => setState(() => verifiedPhone = v)
                            : null,
                      ),
                      const Divider(),
                      _FilterSwitch(
                        title: 'Exclude previously purchased leads',
                        value: excludePurchased,
                        onChanged: (v) => setState(() => excludePurchased = v),
                      ),
                      const Divider(),
                      _FilterSwitch(
                        title: 'Exclude duplicate businesses',
                        value: excludeDuplicates,
                        onChanged: (v) => setState(() => excludeDuplicates = v),
                      ),
                    ],
                  ),
                ),

                // ---- Sort ----
                _head('Sort by'),
                _FilterPill(
                  value: sort.label,
                  allValue: LeadSort.newest.label,
                  options: [for (final s in LeadSort.values) s.label],
                  onSelected: (v) => setState(
                    () => sort = LeadSort.values.firstWhere((s) => s.label == v),
                  ),
                ),

                // ---- Buttons ----
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: searching ? null : _clear,
                        child: const Text('Clear Filters'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: searching ? null : _find,
                        child: searching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Find Leads'),
                      ),
                    ),
                  ],
                ),

                // ---- Results ----
                if (results != null && applied != null)
                  KeyedSubtree(
                    key: resultsKey,
                    child: _buildResults(results!, applied!),
                  ),

                const SizedBox(height: 22),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.info_outline_rounded, size: 14, color: kFaint),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lists are non-exclusive: the same leads may be sold to '
                        'several customers. Demo mode shows generated sample '
                        'data; live inventory comes from Google Sheets.',
                        style: TextStyle(fontSize: 11.5, color: kFaint, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(List<Lead> list, LeadFilters f) {
    final n = list.length;
    final total = leadCoinsFor(f.type, n);
    final preview = list.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(child: Text('Results', style: h2)),
            Text(
              '${formatCount(n)} ${n == 1 ? 'lead' : 'leads'}',
              style: const TextStyle(fontSize: 12, color: kMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (n == 0)
          AppCard(
            padding: const EdgeInsets.all(22),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const IconBadge(icon: Icons.search_off_rounded, size: 46),
                  const SizedBox(height: 12),
                  const Text('No matching leads', style: h2),
                  const SizedBox(height: 4),
                  const Text(
                    'Try a wider location, another category, or switch off '
                    'the verified filters.',
                    textAlign: TextAlign.center,
                    style: bodyMuted,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _clear,
                    child: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SummaryRow(label: 'Matching leads', value: formatCount(n)),
                const Divider(),
                SummaryRow(
                  label: 'Contact details available',
                  value: f.type.guarantee,
                ),
                const Divider(),
                SummaryRow(
                  label: 'Price per 1,000',
                  value: formatMoney(f.type.pricePer1000.toDouble()),
                ),
                const Divider(),
                SummaryRow(
                  label: 'Estimated total price',
                  value: '${formatMoney(total.toDouble())} for all ${formatCount(n)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: buying ? null : _openBuy,
            child: buying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Buy Leads'),
          ),
          const SizedBox(height: 22),
          const Text('Preview', style: h2),
          const SizedBox(height: 4),
          const Text(
            'Contact details stay hidden until you buy.',
            style: bodyMuted,
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0) const Divider(),
                  _LeadPreviewTile(lead: preview[i], type: f.type),
                ],
                if (n > preview.length) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '+ ${formatCount(n - preview.length)} more leads',
                      style: const TextStyle(fontSize: 11.5, color: kMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---- Filter widgets ----

class _ContactTypeCard extends StatelessWidget {
  final ContactType type;
  final bool selected;
  final VoidCallback onTap;

  const _ContactTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? kAccentBright : kLine,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconBadge(icon: type.icon, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: rowTitle),
                    const SizedBox(height: 2),
                    Text(type.blurb, style: rowSub),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${type.pricePer1000}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Text('/ 1,000 leads', style: TextStyle(fontSize: 10, color: kMuted)),
                ],
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? kAccentBright : kFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSwitch extends StatelessWidget {
  final String title;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _FilterSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enabled ? kText : kFaint,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: rowSub),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String value;
  final String allValue;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final bool enabled;

  const _FilterPill({
    required this.value,
    required this.allValue,
    required this.options,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && value != allValue;

    return PopupMenuButton<String>(
      enabled: enabled,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final o in options) PopupMenuItem<String>(value: o, child: Text(o)),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: enabled ? kSurface : kSurfaceHi,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? kAccentBright : kLine),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: !enabled
                      ? kFaint
                      : active
                          ? kAccentBright
                          : kText,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 19,
              color: active ? kAccentBright : kFaint,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Results widgets ----

class _LeadPreviewTile extends StatelessWidget {
  final Lead lead;
  final ContactType type;

  const _LeadPreviewTile({required this.lead, required this.type});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LeadDetailPage(lead: lead, type: type),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(initials: lead.initials, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rowTitle,
                  ),
                  const SizedBox(height: 2),
                  Text('${lead.contactName} · ${lead.jobTitle}', style: rowSub),
                  const SizedBox(height: 4),
                  if (type.needsPhone && lead.hasPhone)
                    Text(
                      maskPhone(lead.phone),
                      style: const TextStyle(fontSize: 11.5, color: kMuted),
                    ),
                  if (type.needsEmail && lead.hasEmail)
                    Text(
                      maskEmail(lead.email),
                      style: const TextStyle(fontSize: 11.5, color: kMuted),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${lead.location} · ${lead.category}',
                    style: const TextStyle(fontSize: 10.5, color: kFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'View Lead',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kAccentBright,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LeadDetailPage extends StatelessWidget {
  final Lead lead;
  final ContactType type;

  const LeadDetailPage({super.key, required this.lead, required this.type});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      SummaryRow(label: 'Contact', value: lead.contactName),
      const Divider(),
      SummaryRow(label: 'Job title', value: lead.jobTitle),
      const Divider(),
      SummaryRow(label: 'Category', value: lead.category),
      const Divider(),
      SummaryRow(label: 'Location', value: '${lead.location}, ${lead.country}'),
      const Divider(),
      SummaryRow(
        label: 'Website',
        value: lead.hasWebsite ? lead.website : 'Not available',
      ),
      if (type.needsPhone && lead.hasPhone) ...[
        const Divider(),
        SummaryRow(label: 'Phone', value: maskPhone(lead.phone)),
        const Divider(),
        SummaryRow(
          label: 'Phone status',
          value: lead.phoneVerified ? 'Verified' : 'Not verified',
          valueColor: lead.phoneVerified ? kGreen : kMuted,
        ),
      ],
      if (type.needsEmail && lead.hasEmail) ...[
        const Divider(),
        SummaryRow(label: 'Email', value: maskEmail(lead.email)),
        const Divider(),
        SummaryRow(
          label: 'Email status',
          value: lead.emailVerified ? 'Verified' : 'Not verified',
          valueColor: lead.emailVerified ? kGreen : kMuted,
        ),
      ],
      const Divider(),
      SummaryRow(label: 'Added', value: formatDate(lead.dateAdded)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead details'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              children: [
                IconBadge(icon: type.icon, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead.company, style: h2.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(lead.id, style: rowSub),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppCard(padding: EdgeInsets.zero, child: Column(children: rows)),
            const SizedBox(height: 16),
            const InfoBullet(
              icon: Icons.lock_outline_rounded,
              text: 'Full phone and email details unlock after you buy. '
                  'Leads are non-exclusive and may be sold to other customers.',
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Quantity + confirm sheet ----

class _BuySheet extends StatefulWidget {
  final ContactType type;
  final int available;

  const _BuySheet({required this.type, required this.available});

  @override
  State<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<_BuySheet> {
  late final List<int> options = _options();
  late int qty = options.first;

  List<int> _options() {
    final a = widget.available;
    final o = <int>[
      for (final n in const [1000, 2500, 5000])
        if (n < a) n,
    ];
    o.add(a);
    return o;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cost = leadCoinsFor(widget.type, qty);
    final enough = state.coins >= cost;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How many leads?', style: h1),
            const SizedBox(height: 4),
            Text(
              '${widget.type.label} · ${formatCount(widget.available)} available',
              style: bodyMuted,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in options)
                  ChoicePill(
                    label: n == widget.available && options.length > 1
                        ? 'All ${formatCount(n)}'
                        : formatCount(n),
                    selected: qty == n,
                    onTap: () => setState(() => qty = n),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SummaryRow(label: 'Leads', value: formatCount(qty)),
                  const Divider(),
                  SummaryRow(
                    label: 'Price',
                    value: '${formatCoins(cost)} (${formatMoney(cost.toDouble())})',
                  ),
                  const Divider(),
                  SummaryRow(
                    label: 'Your balance',
                    value: formatCoins(state.coins),
                    valueColor: enough ? null : kAmber,
                  ),
                  if (enough) ...[
                    const Divider(),
                    SummaryRow(
                      label: 'Balance after',
                      value: formatCoins(state.coins - cost),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Non-exclusive: the same leads may be sold to other customers. '
              'Delivered instantly to My leads.',
              style: TextStyle(fontSize: 11.5, color: kFaint, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: enough
                  ? () => Navigator.of(context).pop(qty)
                  : () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WalletPage()),
                      );
                    },
              child: Text(enough ? 'Buy · ${formatCoins(cost)}' : 'Top up balance'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase result, My leads, order details
// ---------------------------------------------------------------------------

class PurchaseSuccessPage extends StatelessWidget {
  final PurchaseOrder order;

  const PurchaseSuccessPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Purchase complete'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          children: [
            const Center(
              child: IconBadge(icon: Icons.check_rounded, color: kGreen, size: 64),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your leads are ready',
              textAlign: TextAlign.center,
              style: h1,
            ),
            const SizedBox(height: 6),
            Text(
              '${formatCount(order.leads.length)} leads were added to My leads.',
              textAlign: TextAlign.center,
              style: bodyMuted,
            ),
            const SizedBox(height: 24),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SummaryRow(label: 'Order', value: order.id),
                  const Divider(),
                  SummaryRow(label: 'List', value: order.title),
                  const Divider(),
                  SummaryRow(label: 'Paid', value: formatCoins(order.coins)),
                  const Divider(),
                  SummaryRow(label: 'Balance', value: formatCoins(state.coins)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => importOrder(context, order),
              child: Text(orderImportLabel(order)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OrderDetailPage(order: order)),
              ),
              child: const Text('View leads'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyLeadsPage extends StatelessWidget {
  const MyLeadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = AppScope.of(context).orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My leads'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: orders.isEmpty
            ? EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No leads yet',
                message: 'Leads you buy in LeadMarket will show up here.',
                actionLabel: 'Browse LeadMarket',
                onAction: () => Navigator.of(context).pop(),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return AppCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailPage(order: order),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconBadge(icon: order.type.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.title, style: rowTitle),
                              const SizedBox(height: 2),
                              Text(
                                '${order.id} · ${formatDate(order.createdAt)} · '
                                '${formatCount(order.leads.length)} leads',
                                style: rowSub,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: kFaint),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class OrderDetailPage extends StatelessWidget {
  final PurchaseOrder order;

  const OrderDetailPage({super.key, required this.order});

  Future<void> _copy(BuildContext context) async {
    final t = order.type;
    final text = order.leads
        .map(
          (l) => [
            if (t.needsPhone && l.hasPhone) l.phone,
            if (t.needsEmail && l.hasEmail) l.email,
          ].join(', '),
        )
        .where((s) => s.isNotEmpty)
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showToast(context, '${formatCount(order.leads.length)} leads copied.');
  }

  @override
  Widget build(BuildContext context) {
    final leads = order.leads;

    return Scaffold(
      appBar: AppBar(
        title: Text(order.id),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: leads.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SummaryRow(label: 'List', value: order.title),
                          const Divider(),
                          SummaryRow(
                            label: 'Purchased',
                            value: formatDate(order.createdAt),
                          ),
                          const Divider(),
                          SummaryRow(
                            label: 'Leads',
                            value: formatCount(leads.length),
                          ),
                          const Divider(),
                          SummaryRow(label: 'Paid', value: formatCoins(order.coins)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => importOrder(context, order),
                      child: Text(orderImportLabel(order)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _copy(context),
                      child: const Text('Copy all contact details'),
                    ),
                    const SizedBox(height: 22),
                    const Text('Leads', style: h2),
                    const SizedBox(height: 4),
                  ],
                ),
              );
            }
            return _LeadRow(lead: leads[index - 1], type: order.type);
          },
        ),
      ),
    );
  }
}

class _LeadRow extends StatelessWidget {
  final Lead lead;
  final ContactType type;

  const _LeadRow({required this.lead, required this.type});

  @override
  Widget build(BuildContext context) {
    const contactStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: kAccentBright,
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kLine)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(initials: lead.initials, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.contactName, style: rowTitle),
                const SizedBox(height: 2),
                Text('${lead.jobTitle} · ${lead.company}', style: rowSub),
                const SizedBox(height: 3),
                if (type.needsPhone && lead.hasPhone)
                  Text(
                    Contact(name: '', phone: lead.phone).prettyPhone,
                    style: contactStyle,
                  ),
                if (type.needsEmail && lead.hasEmail)
                  Text(lead.email, style: contactStyle),
                const SizedBox(height: 2),
                Text(
                  '${lead.location} · ${lead.category}',
                  style: const TextStyle(fontSize: 10.5, color: kFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LeadCoins wallet (hidden at launch)
// ---------------------------------------------------------------------------

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  static const List<CoinBundle> bundles = [
    CoinBundle(20, 20),
    CoinBundle(50, 50),
    CoinBundle(100, 100),
  ];

  Future<void> _buy(BuildContext context, CoinBundle bundle) async {
    final state = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kLine),
        ),
        title: Text('Buy ${bundle.coins} LeadCoins?', style: const TextStyle(fontSize: 17)),
        content: Text(
          'Price: ${formatMoney(bundle.price)}.\n\n'
          'Demo checkout: no real payment is taken.',
          style: bodyMuted.copyWith(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    state.buyCoins(bundle);
    showToast(context, '${bundle.coins} LeadCoins added.');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LeadCoins'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2542FF), kAccent, Color(0xFF0A1240)],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCount(state.coins),
                    style: const TextStyle(
                      fontSize: 38,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '1 LeadCoin = \$1 of LeadMarket credit',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Get LeadCoins', style: h2),
            const SizedBox(height: 12),
            for (final b in bundles)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _buy(context, b),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const IconBadge(icon: Icons.toll_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('${b.coins} LeadCoins', style: rowTitle),
                      ),
                      Text(
                        formatMoney(b.price),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: kAccentBright,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            const InfoBullet(
              icon: Icons.shield_outlined,
              text: 'LeadCoins only pay for LeadMarket lists. They cannot be '
                  'used for SMS or email charges, which Telnyx bills to your '
                  'own account. Demo mode: no real payment is taken.',
            ),
            const SizedBox(height: 26),
            const Text('History', style: h2),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < state.ledger.length; i++) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.ledger[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: kText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatDate(state.ledger[i].time),
                                  style: rowSub,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${state.ledger[i].amount > 0 ? '+' : ''}'
                            '${state.ledger[i].amount}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: state.ledger[i].amount > 0 ? kGreen : kText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// More (side-menu style settings)
// ---------------------------------------------------------------------------

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final connected = state.provider != null;
    final checked = state.balanceCheckedAt;

    return Column(
      children: [
        // Fixed header
        const PageHeader(title: 'More'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Avatar(
                      radius: 22,
                      initials: state.userName.isEmpty
                          ? ''
                          : state.userName
                              .split(RegExp(r'\s+'))
                              .where((w) => w.isNotEmpty)
                              .take(2)
                              .map((w) => w[0].toUpperCase())
                              .join(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.userName, style: h2),
                          const SizedBox(height: 2),
                          Text(state.userEmail, style: rowSub),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.home_outlined,
                      title: 'Home',
                      onTap: () => state.setTab(kTabHome),
                    ),
                    const Divider(),
                    _MenuRow(
                      icon: Icons.send_outlined,
                      title: 'Campaigns',
                      onTap: () => state.setTab(kTabCampaigns),
                    ),
                    const Divider(),
                    _MenuRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Messages',
                      trailing: state.unreadCount > 0
                          ? Pill('${state.unreadCount} new', color: kAccentBright)
                          : null,
                      onTap: () => state.setTab(kTabMessages),
                    ),
                    const Divider(),
                    _MenuRow(
                      icon: Icons.people_outline_rounded,
                      title: 'Contacts',
                      onTap: () {
                        if (kLeadMarketEnabled) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ContactsPage()),
                          );
                        } else {
                          state.setTab(kTabContacts);
                        }
                      },
                    ),
                    const Divider(),
                    _MenuRow(
                      icon: Icons.storefront_outlined,
                      title: 'Lead Store',
                      trailing: kLeadMarketEnabled
                          ? null
                          : const Pill('Soon', color: kAmber),
                      onTap: () {
                        if (kLeadMarketEnabled) {
                          state.setTab(kTabContacts);
                        } else {
                          showToast(context, 'LeadMarket is opening soon.');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (kLeadMarketEnabled) ...[
                      _MenuRow(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet',
                        value: formatCoins(state.coins),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WalletPage()),
                        ),
                      ),
                      const Divider(),
                    ],
                    _MenuRow(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Subscription',
                      value: state.subscriptionActive ? 'Active' : 'Inactive',
                      onTap: () => showSubscriptionSheet(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Messaging', style: h2),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TelnyxPage()),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            IconBadge(
                              icon: Icons.cell_tower_rounded,
                              color: connected ? kGreen : kAmber,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Telnyx', style: rowTitle),
                                  SizedBox(height: 2),
                                  Text('SMS provider', style: rowSub),
                                ],
                              ),
                            ),
                            Pill(
                              connected ? 'Connected' : 'Not connected',
                              color: connected ? kGreen : kAmber,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TelnyxPage()),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            IconBadge(
                              icon: Icons.account_balance_wallet_outlined,
                              color: connected && state.lowBalance
                                  ? kAmber
                                  : kAccentBright,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Telnyx balance', style: rowTitle),
                                  const SizedBox(height: 2),
                                  Text(
                                    !connected
                                        ? 'Connect Telnyx to see it'
                                        : state.lowBalance
                                            ? 'Running low · add funds in Telnyx'
                                            : checked == null
                                                ? 'Not checked yet'
                                                : 'Checked ${longTimeAgo(checked)}',
                                    style: rowSub,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              connected ? formatMoney(state.telnyxBalance) : '—',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: connected && state.lowBalance ? kAmber : kText,
                              ),
                            ),
                            if (connected) ...[
                              const SizedBox(width: 6),
                              state.refreshingBalance
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: kAccentBright,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Refresh balance',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 19,
                                        color: kAccentBright,
                                      ),
                                      onPressed: () => state.refreshBalance(),
                                    ),
                            ] else
                              const Icon(Icons.chevron_right_rounded, color: kFaint),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoBullet(
                icon: Icons.account_balance_wallet_outlined,
                text: kLeadMarketEnabled
                    ? 'Subscription, LeadCoins and your Telnyx balance are '
                        'billed separately and never mixed.'
                    : 'Your LeadText subscription and your Telnyx balance are '
                        'billed separately. Telnyx charges for messages go to '
                        'your own Telnyx account.',
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TelnyxPage()),
                      ),
                    ),
                    const Divider(),
                    _MenuRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () => showToast(
                        context,
                        'Help centre is coming soon.',
                      ),
                    ),
                    const Divider(),
                    _MenuRow(
      icon: Icons.logout_rounded,
      title: 'Log out',
      color: kRed,
      showChevron: false,
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Log out'),
              content: const Text('Are you sure you want to log out of LeadText?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(), // Close dialog, do nothing
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close dialog first
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    state.signOut();
                  },
                  child: const Text('Log out', style: TextStyle(color: kRed)),
                ),
              ],
            );
          },
        );
      },
    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Before you send', style: h2),
              const SizedBox(height: 10),
              const AppCard(
                child: Column(
                  children: [
                    InfoBullet(
                      icon: Icons.verified_outlined,
                      text: 'Register your number for business messaging '
                          '(for example A2P 10DLC in the US).',
                    ),
                    SizedBox(height: 14),
                    InfoBullet(
                      icon: Icons.how_to_reg_outlined,
                      text: 'Only contact people you have a lawful basis to '
                          'contact. Providers may restrict purchased lists.',
                    ),
                    SizedBox(height: 14),
                    InfoBullet(
                      icon: Icons.block_outlined,
                      text: 'Always include an opt-out line and honour STOP '
                          'and unsubscribe replies.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Center(
                child: Text(
                  'LeadText · A JML Product · v1.0.0',
                  style: TextStyle(fontSize: 11.5, color: kFaint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final Color color;
  final bool showChevron;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.trailing,
    this.color = kText,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color == kText ? kMuted : color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 6),
            ],
            if (value != null)
              Text(value!, style: const TextStyle(fontSize: 12, color: kMuted)),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20, color: kFaint),
            ],
          ],
        ),
      ),
    );
  }
}

/// Balance card shown at the top of the Telnyx page once connected.
class TelnyxBalanceCard extends StatelessWidget {
  const TelnyxBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final checked = state.balanceCheckedAt;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: FieldLabel('Account balance')),
              if (state.lowBalance) const Pill('Low', color: kAmber),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(state.telnyxBalance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: kText,
              letterSpacing: -1.0,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '≈ ${formatCount(state.smsLeft)} SMS'
            '${checked == null ? '' : ' · checked ${longTimeAgo(checked)}'}',
            style: rowSub,
          ),
          if (state.lowBalance) ...[
            const SizedBox(height: 10),
            const Text(
              'Your balance is running low. Add funds in Telnyx so your '
              'campaigns keep delivering.',
              style: TextStyle(fontSize: 12, color: kAmber, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => state.refreshBalance(),
                  icon: state.refreshingBalance
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => addTelnyxFunds(context),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Add funds'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Telnyx (real connection through the `telnyx` Edge Function)
// ---------------------------------------------------------------------------

class TelnyxPage extends StatefulWidget {
  const TelnyxPage({super.key});

  @override
  State<TelnyxPage> createState() => _TelnyxPageState();
}

class _TelnyxPageState extends State<TelnyxPage> {
  final keyController = TextEditingController();
  final numberController = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    // Always show the live state (balance, reply webhook) when the page opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).loadTelnyxStatus();
    });
  }

  @override
  void dispose() {
    keyController.dispose();
    numberController.dispose();
    super.dispose();
  }

  String? _validate() {
    final key = keyController.text.trim();
    final number = numberController.text.trim();

    if (!key.startsWith('KEY') || key.length < 20) {
      return 'Telnyx API keys start with "KEY". Create one in your Telnyx portal under API Keys.';
    }
    if (_normalizePhone(number) == null) {
      return 'Enter your Telnyx sending number, e.g. +14155550101.';
    }
    return null;
  }

  Future<void> _connect() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      error = null;
      busy = true;
    });

    final state = AppScope.of(context);
    try {
      // The key is sent once over HTTPS, validated with Telnyx, then stored
      // encrypted on the server. It is never kept on this device.
      final res = await Supabase.instance.client.functions.invoke(
        'telnyx',
        body: {
          'action': 'connect',
          'api_key': keyController.text.trim(),
          'sms_number': _normalizePhone(numberController.text.trim()),
        },
      );
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Could not connect Telnyx.');
      }

      keyController.clear();
      numberController.clear();
      await state.loadTelnyxStatus();
      if (!mounted) return;
      showToast(
        context,
        data['webhook_warning'] != null
            ? 'Connected, but replies are not set up yet: ${data['webhook_warning']}'
            : 'Telnyx connected. Replies will show up in Messages.',
      );
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Telnyx?'),
        content: const Text(
          'LeadText will forget your key and stop sending. Replies will no longer arrive until you connect again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final state = AppScope.of(context);
    setState(() => busy = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'telnyx',
        body: {'action': 'disconnect'},
      );
      state.clearTelnyx();
      if (mounted) showToast(context, 'Telnyx disconnected.');
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final connection = state.provider;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telnyx'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Your Telnyx account', style: h2)),
                Pill(
                  connection != null ? 'Connected' : 'Not connected',
                  color: connection != null ? kGreen : kAmber,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Messages send from your own Telnyx account and number. You fund '
              'your Telnyx balance directly; LeadText never pays for it.',
              style: bodyMuted,
            ),
            const SizedBox(height: 16),
            if (connection != null) ...[
              const TelnyxBalanceCard(),
              const SizedBox(height: 14),
              if (state.telnyxKeyInvalid) ...[
                const AppCard(
                  child: InfoBullet(
                    icon: Icons.error_outline_rounded,
                    text: 'Telnyx rejected the saved API key. Disconnect, then '
                        'connect again with a new key.',
                  ),
                ),
                const SizedBox(height: 14),
              ],
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SummaryRow(label: 'API key', value: connection.maskedKey),
                    const Divider(),
                    SummaryRow(label: 'SMS number', value: connection.smsNumber),
                    const Divider(),
                    SummaryRow(
                      label: 'Incoming replies',
                      value: state.telnyxWebhookOk ? 'Connected' : 'Not set up',
                      valueColor: state.telnyxWebhookOk ? kGreen : kAmber,
                    ),
                    if (!state.telnyxWebhookOk) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: InfoBullet(
                          icon: Icons.warning_amber_rounded,
                          text: 'Replies cannot reach the Messages tab yet. '
                              'Disconnect and connect again to retry the setup.',
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: TextButton(
                        onPressed: busy ? null : _disconnect,
                        style: TextButton.styleFrom(foregroundColor: kRed),
                        child: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('API key'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: keyController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(hintText: 'KEY…'),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('SMS sending number'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: numberController,
                      keyboardType: TextInputType.phone,
                      autocorrect: false,
                      decoration: const InputDecoration(hintText: '+14155550101'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: kRed,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy ? null : _connect,
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save & test connection'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your key is checked with Telnyx, then stored encrypted on '
                      'our server. It is never saved on your device.',
                      style: TextStyle(fontSize: 11.5, color: kFaint, height: 1.5),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            const Text('Before you connect', style: h2),
            const SizedBox(height: 10),
            const AppCard(
              child: Column(
                children: [
                  InfoBullet(
                    icon: Icons.vpn_key_outlined,
                    text: 'In the Telnyx portal create an API key (Auth → API '
                        'Keys). It starts with "KEY".',
                  ),
                  SizedBox(height: 14),
                  InfoBullet(
                    icon: Icons.phone_iphone_rounded,
                    text: 'Use a number that is already on your Telnyx account '
                        'and has messaging enabled.',
                  ),
                  SizedBox(height: 14),
                  InfoBullet(
                    icon: Icons.verified_outlined,
                    text: 'US numbers must be registered (10DLC or toll-free '
                        'verification) before carriers deliver your texts.',
                  ),
                  SizedBox(height: 14),
                  InfoBullet(
                    icon: Icons.sync_alt_rounded,
                    text: 'Connecting points your number\'s messaging profile '
                        'webhook at LeadText so replies appear in Messages.',
                  ),
                  SizedBox(height: 14),
                  InfoBullet(
                    icon: Icons.mail_outline_rounded,
                    text: 'Telnyx handles SMS only. Email sending is not '
                        'available yet.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subscription (ONE card, used everywhere)
// ---------------------------------------------------------------------------

/// Must match SUBSCRIPTION_PRICE_NGN in the initialize-payment Edge Function.
const int kSubscriptionPriceNgn = 35000;

String formatNaira(int n) => '₦${formatCount(n)}';

/// The only entry point to the subscription card. Used by the welcome prompt,
/// the "Subscription inactive" badge, the More tab and blocked actions.
void showSubscriptionSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: kBg,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.94,
      child: SubscriptionPage(),
    ),
  );
}

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool busy = false;

  Future<void> _pay() async {
    if (busy) return;
    setState(() => busy = true);
    final state = AppScope.of(context);
    final done = await startLeadTextSubscription(context);
    if (!mounted) return;
    setState(() => busy = false);
    if (done && state.subscriptionActive) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final active = state.subscriptionActive;
    final end = state.periodEnd;

    return Material(
      color: kBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Row(
            children: [
              const Expanded(child: Text('LeadText Pro', style: h1)),
              Pill(
                active ? 'Active' : 'Inactive',
                color: active ? kGreen : kAmber,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Everything you need to reach more customers.',
            style: bodyMuted,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2542FF), kAccent, Color(0xFF0A1240)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LEADTEXT PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatNaira(kSubscriptionPriceNgn),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/ month',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                _buildFeatureRow('Bulk SMS campaigns'),
                _buildFeatureRow('1-to-1 messaging with replies'),
                _buildFeatureRow('Contact import and management'),
                _buildFeatureRow('LeadMarket access'),
                _buildFeatureRow('300 LeadCoins included every month'),
                _buildFeatureRow('Campaign tracking and history'),
                _buildFeatureRow('Bring your own Telnyx account'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SummaryRow(
                  label: active ? 'Active until' : 'Status',
                  value: active && end != null
                      ? formatDate(end)
                      : active
                          ? 'Active'
                          : 'Not subscribed',
                ),
                const Divider(),
                const SummaryRow(label: 'Includes', value: '300 LeadCoins / month'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Paid securely with Paystack. Each payment adds one month, so '
            'there is nothing to cancel. SMS charges are billed separately by '
            'your own Telnyx account.',
            style: TextStyle(fontSize: 11.5, color: kFaint, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : _pay,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    active
                        ? 'Renew for another month'
                        : 'Subscribe · ${formatNaira(kSubscriptionPriceNgn)} / month',
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _buildFeatureRow(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

/// Starts a Paystack payment, waits for the user to come back, then asks the
/// server to verify it (the server checks with Paystack before activating).
/// Returns true when the subscription was activated.
Future<bool> startLeadTextSubscription(BuildContext context) async {
  final client = Supabase.instance.client;
  final appState = AppScope.of(context);

  void say(String message) {
    kMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  if (client.auth.currentSession == null) {
    say('Please sign in before subscribing.');
    return false;
  }

  var busyOpen = false;
  void showBusy() {
    if (busyOpen || !context.mounted) return;
    busyOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void hideBusy() {
    if (!busyOpen) return;
    busyOpen = false;
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  try {
    showBusy();
    final init = await client.functions.invoke(
      'initialize-payment',
      body: {'payment_type': 'subscription'},
    );
    final initData = Map<String, dynamic>.from(init.data as Map);
    final checkoutUrl = initData['authorization_url'] as String?;
    final reference = initData['reference'] as String?;
    if (checkoutUrl == null || reference == null) {
      throw Exception('Payment setup did not return a checkout link.');
    }
    hideBusy();

    final opened = await launchUrl(
      Uri.parse(checkoutUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw Exception('Could not open the Paystack checkout. Please try again.');
    }

    // The user pays in the browser, comes back, and confirms here. Nothing is
    // activated until the server has verified the payment with Paystack.
    while (true) {
      if (!context.mounted) return false;
      final verify = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Complete your subscription'),
          content: const Text(
            'Finish the payment in the Paystack page, then come back here and '
            'tap "I have paid" to activate your subscription.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('I have paid'),
            ),
          ],
        ),
      );
      if (verify != true || !context.mounted) return false;

      showBusy();
      try {
        final res = await client.functions.invoke(
          'verify-payment',
          body: {'reference': reference},
        );
        final data = Map<String, dynamic>.from(res.data as Map);
        hideBusy();

        if (data['success'] == true && data['payment_status'] == 'paid') {
          await appState.refreshBilling(); // real balance + status from the server
          final coins = (data['coins_awarded'] as num?)?.toInt() ?? 0;
          say(
            coins > 0
                ? 'Subscription active. ${formatCount(coins)} LeadCoins added.'
                : 'Subscription active.',
          );
          return true;
        }
        say(data['message']?.toString() ?? 'Payment is not confirmed yet.');
      } catch (e) {
        hideBusy();
        say(friendlyError(e)); // not confirmed yet: the dialog opens again
      }
    }
  } catch (e) {
    hideBusy();
    say(friendlyError(e));
    return false;
  }
}