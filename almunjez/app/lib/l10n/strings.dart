import 'package:flutter/widgets.dart';

import '../core/models/enums.dart';

/// Arabic-first strings. English is a complete second locale; Arabic is the
/// design language, so keys are named after the Arabic meaning.
class S {
  const S(this.locale);
  final String locale;

  static S of(BuildContext context) => S(Localizations.localeOf(context).languageCode);
  bool get ar => locale != 'en';

  String t(String a, String e) => ar ? a : e;

  // app
  String get appName => t('المنجز', 'AlMunjez');
  String get tagline => t('كل مهمة لها صاحب', 'Every task has an owner');

  // tabs
  String get home => t('الرئيسية', 'Home');
  String get myTasks => t('مهامي', 'My Tasks');
  String get groups => t('المجموعات', 'Groups');
  String get notifications => t('الإشعارات', 'Notifications');
  String get newTaskCta => t('+ مهمة', '+ Task');

  // auth
  String get welcome1Title => t('كل مهمة لها صاحب', 'Every task has an owner');
  String get welcome1Body => t('حوّل ما يُقال في المجموعة إلى مسؤولية واضحة لها صاحب وحالة وسجل.', 'Turn what gets discussed into a clear responsibility with an owner, a status and a record.');
  String get welcome2Title => t('سأتولى المهمة', "I'll take it");
  String get welcome2Body => t('تظهر المهمة، يفهمها العضو، يضغط زراً واحداً ويصبح مسؤولاً عنها أمام الجميع.', 'A task appears, a member understands it, taps once, and owns it in front of everyone.');
  String get welcome3Title => t('للبيت والعمل', 'For home and work');
  String get welcome3Body => t('مجموعات خاصة بموافقة على الانضمام: العائلة، الشركة، الفريق، اللجنة.', 'Private groups with join approval: family, company, team, committee.');
  String get signIn => t('تسجيل الدخول', 'Sign in');
  String get signInWithApple => t('المتابعة بحساب Apple', 'Continue with Apple');
  String get signInWithGoogle => t('المتابعة بحساب Google', 'Continue with Google');
  String get signInWithPhone => t('المتابعة برقم الجوال', 'Continue with phone');
  String get signInDemo => t('تجربة سريعة بحساب تجريبي', 'Quick demo account');
  String get phoneNumber => t('رقم الجوال', 'Phone number');
  String get sendCode => t('إرسال الرمز', 'Send code');
  String get verificationCode => t('رمز التحقق', 'Verification code');
  String get codeSentTo => t('أرسلنا رمزاً إلى', 'We sent a code to');
  String get signInWithEmail => t('المتابعة بالبريد الإلكتروني', 'Continue with email');
  String get email => t('البريد الإلكتروني', 'Email');
  String get password => t('كلمة المرور', 'Password');
  String get passwordHint => t('٨ أحرف على الأقل', 'At least 8 characters');
  String get createAccount => t('إنشاء حساب', 'Create account');
  String get haveAccount => t('لديك حساب؟ تسجيل الدخول', 'Have an account? Sign in');
  String get noAccount => t('ليس لديك حساب؟ أنشئ واحداً', 'No account? Create one');
  String get useEmailCode => t('الدخول برمز يُرسل إلى البريد بدل كلمة المرور', 'Use an emailed code instead of a password');
  String get usePassword => t('الدخول بكلمة المرور', 'Use a password instead');
  String get confirmEmailSent => t('أرسلنا رابط تأكيد إلى بريدك. اضغطه، ثم عد هنا وسجّل الدخول بكلمة المرور. (إن ظهرت صفحة فارغة بعد الضغط فهذا طبيعي — التأكيد تم.)', 'We sent a confirmation link to your email. Open it, then come back and sign in with your password. (A blank page after clicking is normal — the confirmation went through.)');
  String get verify => t('تحقق', 'Verify');
  String get or => t('أو', 'or');
  String get completeProfile => t('إكمال الملف', 'Complete your profile');
  String get yourName => t('اسمك كما يراه الأعضاء', 'Your name as members see it');
  String get continueLabel => t('متابعة', 'Continue');
  String get notificationsPermissionTitle => t('نُخبرك حين تحتاج فقط', 'We only notify you when it matters');
  String get notificationsPermissionBody => t('مهمة جديدة، مهمة أُسندت إليك، موعد يقترب، وطلب انضمام ينتظر قرارك. لا شيء آخر.', 'A new task, a task assigned to you, an approaching deadline, and a join request waiting for you. Nothing else.');
  String get enable => t('تفعيل', 'Enable');
  String get later => t('لاحقاً', 'Later');
  String get skip => t('تخطٍّ', 'Skip');

  // home
  String greeting(String name) {
    final h = DateTime.now().hour;
    if (ar) return h < 12 ? 'صباح الخير $name' : 'مساء الخير $name';
    return h < 12 ? 'Good morning, $name' : 'Good evening, $name';
  }
  String get today => t('اليوم', 'Today');
  String get newTasks => t('جديدة', 'New');
  String get inProgress => t('قيد التنفيذ', 'In progress');
  String get completedToday => t('أُنجزت اليوم', 'Done today');
  String get myGroups => t('مجموعاتي', 'My groups');
  String get pendingJoinRequests => t('طلبات انضمام تنتظرك', 'Join requests waiting for you');
  String get createFirstGroup => t('أنشئ مجموعتك الأولى', 'Create your first group');
  String get haveCode => t('لديك رمز دعوة؟', 'Have an invite code?');
  String get nothingToday => t('لا شيء عليك اليوم', 'Nothing on you today');
  String get nothingTodayBody => t('حين تُسند إليك مهمة أو تتولاها ستظهر هنا.', 'Tasks assigned to you or claimed by you will show here.');

  // sections
  String get overdue => t('متأخرة', 'Overdue');
  String get noDate => t('بلا موعد', 'No date');
  String get upcoming => t('قادمة', 'Upcoming');
  String get personal => t('الخاصة', 'Personal');
  String get personalTasks => t('مهامي الخاصة', 'My private tasks');
  String get noPersonalTasks => t('لا مهام خاصة بعد', 'No private tasks yet');

  // groups
  String get createGroup => t('إنشاء مجموعة', 'Create group');
  String get joinGroup => t('الانضمام إلى مجموعة', 'Join a group');
  String get groupName => t('اسم المجموعة', 'Group name');
  String get groupType => t('نوع المجموعة', 'Group type');
  String get create => t('إنشاء', 'Create');
  String get inviteMembers => t('دعوة الأعضاء', 'Invite members');
  String get inviteCode => t('رمز الدعوة', 'Invite code');
  String get inviteHint => t('من يملك الرمز يطلب الانضمام فقط؛ أنت من يقبل.', 'Anyone with the code can only request to join; you decide.');
  String get copyCode => t('نسخ الرمز', 'Copy code');
  String get share => t('مشاركة', 'Share');
  String get regenerateCode => t('إعادة توليد الرمز', 'Regenerate code');
  String get revokeInvites => t('إيقاف الدعوات', 'Stop invitations');
  String get invitesStopped => t('الدعوات متوقفة', 'Invitations are off');
  String get enterCode => t('أدخل رمز الدعوة', 'Enter the invite code');
  String get scanQr => t('مسح رمز QR', 'Scan QR');
  String get checkCode => t('تحقق من الرمز', 'Check code');
  String get requestJoin => t('طلب الانضمام', 'Request to join');
  String get requestSent => t('أُرسل طلبك، بانتظار الموافقة', 'Request sent, awaiting approval');
  String get alreadyMember => t('أنت عضو بالفعل', 'You are already a member');
  String get pendingApproval => t('بانتظار الموافقة', 'Awaiting approval');
  String members(int n) => ar ? '$n أعضاء' : '$n members';
  String get membersTitle => t('الأعضاء', 'Members');
  String get activityLog => t('سجل النشاط', 'Activity');
  String get groupSettings => t('إعدادات المجموعة', 'Group settings');
  String get stats => t('الإحصاءات', 'Statistics');
  String get joinRequests => t('طلبات الانضمام', 'Join requests');
  String get accept => t('قبول', 'Accept');
  String get reject => t('رفض', 'Reject');
  String get noRequests => t('لا طلبات معلقة', 'No pending requests');
  String get openTasks => t('مفتوحة', 'Open');
  String get all => t('الكل', 'All');
  String get mine => t('لي', 'Mine');
  String get completed => t('مكتملة', 'Completed');
  String get noTasksHere => t('لا مهام هنا', 'No tasks here');
  String get noTasksHereBody => t('أضف أول مهمة ليعرف الجميع ما يجب فعله.', 'Add the first task so everyone knows what needs doing.');
  String get makeAdmin => t('ترقية إلى مشرف', 'Make admin');
  String get removeAdmin => t('إلغاء الإشراف', 'Remove admin');
  String get removeFromGroup => t('إزالة من المجموعة', 'Remove from group');
  String get transferOwnership => t('نقل الملكية', 'Transfer ownership');
  String get leaveGroup => t('مغادرة المجموعة', 'Leave group');
  String get archiveGroup => t('أرشفة المجموعة', 'Archive group');
  String get ownerMustTransfer => t('انقل الملكية إلى عضو آخر أولاً', 'Transfer ownership to another member first');
  String get requiresApprovalDefault => t('اعتماد الإنجاز افتراضياً', 'Require approval by default');
  String get requiresApprovalDefaultHint => t('كل مهمة جديدة تحتاج اعتماد المنشئ أو مشرف عند إنجازها', 'Every new task needs the creator or an admin to approve completion');
  String get gamification => t('النقاط والترتيب', 'Points and leaderboard');
  String get gamificationHint => t('اجعل للمهام نقاطاً واعرض ترتيب المساهمة', 'Give tasks points and show a contribution ranking');
  String get membersCanCreate => t('الأعضاء ينشئون مهاماً', 'Members can create tasks');
  String get activityVisible => t('سجل النشاط مرئي للأعضاء', 'Activity visible to members');
  String get statsVisibility => t('من يرى إحصاءات الأعضاء', 'Who sees member statistics');
  String get statsPrivate => t('كلٌّ يرى إحصاءاته فقط', 'Each member sees only their own');
  String get statsAdmins => t('المشرفون يرون الجميع', 'Admins see everyone');
  String get statsAll => t('الجميع يرى الجميع', 'Everyone sees everyone');
  String get save => t('حفظ', 'Save');
  String get archived => t('مؤرشفة', 'Archived');

  // tasks
  String get newTask => t('مهمة جديدة', 'New task');
  String get editTask => t('تعديل المهمة', 'Edit task');
  String get taskTitle => t('ما المطلوب؟', 'What needs doing?');
  String get description => t('تفاصيل (اختياري)', 'Details (optional)');
  String get group => t('المجموعة', 'Group');
  String get personalNoGroup => t('خاصة — بلا مجموعة', 'Private, no group');
  String get assignment => t('من ينفّذها؟', 'Who does it?');
  String get modeOpen => t('مفتوحة', 'Open');
  String get modeOpenHint => t('أي عضو يضغط «سأتولى المهمة»', 'Any member can tap "I\'ll take it"');
  String get modeAssigned => t('محددة', 'Assigned');
  String get modeAssignedHint => t('تُسند لعضو بعينه', 'Given to a specific member');
  String get modeCollaborative => t('تعاونية', 'Collaborative');
  String get modeCollaborativeHint => t('عدة أعضاء يعملون معاً', 'Several members work together');
  String get assignee => t('المسؤول', 'Assignee');
  String get participants => t('المشاركون', 'Participants');
  String get dueDate => t('الموعد', 'Due');
  String get noDueDate => t('بلا موعد', 'No deadline');
  String get priority => t('الأولوية', 'Priority');
  String get moreOptions => t('خيارات إضافية', 'More options');
  String get points => t('النقاط', 'Points');
  String get requireApproval => t('يحتاج اعتماد الإنجاز', 'Needs completion approval');
  String get requireProof => t('يحتاج إثبات إنجاز', 'Needs proof of completion');
  String get add => t('إضافة', 'Add');
  String get claim => t('سأتولى المهمة', "I'll take it");
  String get start => t('ابدأ', 'Start');
  String get markDone => t('تم الإنجاز', 'Done');
  String get approve => t('اعتماد', 'Approve');
  String get sendBack => t('إرجاع', 'Send back');
  String get sendBackReason => t('سبب الإرجاع', 'Reason');
  String get release => t('التنازل عن المهمة', 'Give up the task');
  String get reassign => t('تغيير المسؤول', 'Reassign');
  String get unassign => t('جعلها مفتوحة', 'Make it open');
  String get cancelTask => t('إلغاء المهمة', 'Cancel task');
  String get reopen => t('إعادة فتح', 'Reopen');
  String get edit => t('تعديل', 'Edit');
  String get comments => t('التعليقات', 'Comments');
  String get writeComment => t('اكتب تعليقاً…', 'Write a comment…');
  String get send => t('إرسال', 'Send');
  String get completionNote => t('ملاحظة الإنجاز (اختياري)', 'Completion note (optional)');
  String get proofNote => t('اكتب ما يثبت الإنجاز', 'Describe what proves completion');
  String get createdBy => t('أنشأها', 'Created by');
  String get subtasks => t('المهام الفرعية', 'Subtasks');
  String get addSubtask => t('مهمة فرعية', 'Subtask');
  String get history => t('السجل', 'History');
  String claimedByOther(String name) => t('تولّاها $name قبل قليل', '$name took it just now');

  // states
  String status(TaskStatus s) => switch (s) {
        TaskStatus.newTask => t('جديدة', 'New'),
        TaskStatus.inProgress => t('قيد التنفيذ', 'In progress'),
        TaskStatus.awaitingApproval => t('بانتظار الاعتماد', 'Awaiting approval'),
        TaskStatus.completed => t('مكتملة', 'Completed'),
        TaskStatus.cancelled => t('ملغاة', 'Cancelled'),
      };
  String get available => t('متاحة', 'Available');
  String get forYou => t('لك', 'for you');
  String priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.low => t('منخفضة', 'Low'),
        TaskPriority.normal => t('عادية', 'Normal'),
        TaskPriority.high => t('مهمة', 'High'),
        TaskPriority.urgent => t('عاجلة', 'Urgent'),
      };
  String groupTypeLabel(GroupType g) => switch (g) {
        GroupType.home => t('البيت', 'Home'),
        GroupType.family => t('العائلة', 'Family'),
        GroupType.company => t('شركة', 'Company'),
        GroupType.department => t('إدارة', 'Department'),
        GroupType.team => t('فريق', 'Team'),
        GroupType.project => t('مشروع', 'Project'),
        GroupType.committee => t('لجنة', 'Committee'),
        GroupType.volunteer => t('فريق تطوعي', 'Volunteer group'),
        GroupType.other => t('أخرى', 'Other'),
      };
  String roleLabel(MembershipRole r) => switch (r) {
        MembershipRole.owner => t('المالك', 'Owner'),
        MembershipRole.admin => t('مشرف', 'Admin'),
        MembershipRole.member => t('عضو', 'Member'),
      };

  // notifications
  String get markAllRead => t('تعليم الكل كمقروء', 'Mark all read');
  String get noNotifications => t('لا إشعارات', 'No notifications');

  // notification preferences (G3, doc 08 §5)
  String get notificationSettingsTitle => t('إعدادات الإشعارات', 'Notification settings');
  String get notifCatTasks => t('مستجدات المهام', 'Task updates');
  String get notifCatTasksHint => t('مهمة جديدة، أُسندت إليك، تولّاها أحد، أُنجزت أو أُلغيت', 'New task, assigned to you, claimed, completed or cancelled');
  String get notifCatDeadlines => t('المواعيد والتذكيرات', 'Deadlines & reminders');
  String get notifCatDeadlinesHint => t('اقتراب الموعد وتأخر المهمة', 'Approaching deadlines and overdue tasks');
  String get notifCatGroups => t('نشاط المجموعات', 'Group activity');
  String get notifCatGroupsHint => t('طلبات الانضمام، تغيّر الأدوار، نقل الملكية', 'Join requests, role changes, ownership transfer');
  String get notifCatComments => t('التعليقات', 'Comments');
  String get notifCatCommentsHint => t('تعليق جديد على مهمة تشارك فيها', 'A new comment on a task you are part of');

  // search
  String get search => t('البحث', 'Search');
  String get searchHint => t('ابحث في المهام والمجموعات والأعضاء', 'Search tasks, groups and members');
  String get noResults => t('لا نتائج', 'No results');
  String get tasks => t('المهام', 'Tasks');

  // profile & settings
  String get profile => t('الملف الشخصي', 'Profile');
  String get settings => t('الإعدادات', 'Settings');
  String get language => t('اللغة', 'Language');
  String get signOut => t('تسجيل الخروج', 'Sign out');
  String get deleteAccount => t('حذف الحساب', 'Delete account');
  String get deleteAccountBody => t('تُحذف مهامك الخاصة وبياناتك، وتبقى مساهماتك في المجموعات باسم «عضو سابق». لا يمكن التراجع.', 'Your private tasks and data are deleted; your group contributions remain as "former member". This cannot be undone.');
  String get thisWeek => t('هذا الأسبوع', 'This week');
  String get thisMonth => t('هذا الشهر', 'This month');
  String get onTime => t('في الوقت', 'On time');
  String get late => t('متأخرة', 'Late');
  String get leaderboard => t('الترتيب', 'Leaderboard');
  String get onlyYourStats => t('تُعرض إحصاءاتك فقط بحسب إعداد المجموعة', 'Only your numbers are shown per the group setting');

  // generic
  String get cancel => t('إلغاء', 'Cancel');
  String get confirm => t('تأكيد', 'Confirm');
  String get ok => t('حسناً', 'OK');
  String get retry => t('إعادة المحاولة', 'Retry');
  String get delete => t('حذف', 'Delete');
  String get loading => t('جارٍ التحميل…', 'Loading…');
  String get offlineMode => t('وضع محلي — البيانات على هذا الجهاز فقط', 'Local mode, data stays on this device');
  String get you => t('أنت', 'You');
  String get formerMember => t('عضو سابق', 'Former member');
  String get by => t('بواسطة', 'by');

  /// Arabic copy for backend error codes (doc 09 §4).
  String error(String code, [Map<String, dynamic> detail = const {}]) => switch (code) {
        'not_a_member' => t('لست عضواً في هذه المجموعة', 'You are not a member of this group'),
        'permission_denied' => t('لا تملك صلاحية هذا الإجراء', 'You do not have permission for this'),
        'already_claimed' => claimedByOther((detail['assignee_name'] as String?) ?? t('عضو آخر', 'another member')),
        'invalid_transition' => t('لا يمكن تنفيذ هذا الإجراء في الحالة الحالية', 'This action is not possible in the current state'),
        'stale_version' => t('عُدّلت المهمة من شخص آخر، حدّث الشاشة', 'Someone else edited the task, refresh'),
        'proof_required' => t('أرفق إثبات الإنجاز أولاً', 'Attach proof of completion first'),
        'invalid_invite' => t('رمز الدعوة غير صحيح أو مُلغى', 'Invalid or revoked invite code'),
        'already_member' => alreadyMember,
        'owner_must_transfer' => ownerMustTransfer,
        'rate_limited' => t('حاول بعد قليل', 'Try again shortly'),
        'not_found' => t('العنصر غير موجود', 'Not found'),
        'unauthenticated' => t('سجّل الدخول أولاً', 'Sign in first'),
        'assignee_required' || 'assignee_not_member' || 'participant_not_member' => t('اختر عضواً من المجموعة', 'Choose a member of the group'),
        'reason_required' => t('اكتب سبب الإرجاع', 'Write a reason'),
        'group_archived' => t('المجموعة مؤرشفة', 'The group is archived'),
        'display_name_required' => t('اكتب اسمك', 'Enter your name'),
        'network' => t('تعذّر الاتصال بالخادم', 'Could not reach the server'),
        // Auth backend errors vary by provider/config (e.g. no SMS provider set up
        // yet) — show Supabase's own message rather than a generic fallback.
        'weak_password' => passwordHint,
        String c when c.startsWith('auth_') => _authMessage(detail['message'] as String?),
        _ => t('حدث خطأ غير متوقع', 'Something went wrong'),
      };

  /// Supabase Auth returns English messages; translate the common ones.
  String _authMessage(String? m) {
    final x = (m ?? '').toLowerCase();
    if (x.contains('invalid login credentials')) return t('البريد أو كلمة المرور غير صحيحة', 'Wrong email or password');
    if (x.contains('email not confirmed')) return t('أكّد بريدك أولاً من رابط التأكيد الذي أرسلناه، ثم سجّل الدخول', 'Confirm your email from the link we sent, then sign in');
    if (x.contains('already registered')) return t('هذا البريد مسجّل بالفعل — سجّل الدخول', 'This email is already registered — sign in');
    if (x.contains('password should be')) return passwordHint;
    if (x.contains('rate limit') || x.contains('too many')) return t('حاول بعد قليل', 'Try again shortly');
    if (x.contains('unsupported phone provider') || x.contains('sms')) return t('الدخول بالجوال غير مفعّل بعد — استخدم البريد', 'Phone sign-in is not enabled yet — use email');
    return m == null || m.isEmpty ? t('خطأ في تسجيل الدخول', 'Sign-in error') : m;
  }

  /// Notification titles rendered on the client from type + data (doc 08 §2).
  String notificationTitle(String type, Map<String, dynamic> d, {String? actor, String? group}) {
    final title = (d['title'] as String?) ?? '';
    final a = actor ?? t('عضو', 'A member');
    final g = group ?? t('المجموعة', 'the group');
    return switch (type) {
      'task.created' => t('مهمة جديدة في $g: $title', 'New task in $g: $title'),
      'task.assigned' => t('أُسندت إليك: $title', 'Assigned to you: $title'),
      'task.claimed' => t('$a تولّى: $title', '$a took: $title'),
      'task.released' => t('$a تنازل عن: $title', '$a gave up: $title'),
      'task.completed' => t('$a أنجز: $title', '$a completed: $title'),
      'task.submitted' => t('بانتظار اعتمادك: $title', 'Awaiting your approval: $title'),
      'task.approved' => t('اعتُمد إنجازك: $title', 'Your completion was approved: $title'),
      'task.rejected' => t('أُعيدت إليك: $title', 'Sent back to you: $title'),
      'task.reassigned' => t('تغيّر المسؤول عن: $title', 'Assignee changed: $title'),
      'task.unassigned' => t('أصبحت مفتوحة: $title', 'Now open: $title'),
      'task.cancelled' => t('أُلغيت: $title', 'Cancelled: $title'),
      'task.updated' => t('تعدّلت: $title', 'Updated: $title'),
      'task.comment' => t('$a علّق على: $title', '$a commented on: $title'),
      'task.due_soon' => t('تقترب مهلة: $title', 'Deadline approaching: $title'),
      'task.overdue' => t('تأخرت: $title', 'Overdue: $title'),
      'join.requested' => t('طلب انضمام: $a إلى $g', 'Join request: $a to $g'),
      'join.accepted' => t('تم قبولك في $g', 'You were accepted into $g'),
      'join.rejected' => t('لم يُقبل طلبك للانضمام إلى $g', 'Your request to join $g was not accepted'),
      'member.removed' => t('أُزلت من $g', 'You were removed from $g'),
      'member.role_changed' => t('تغيّر دورك في $g', 'Your role in $g changed'),
      'group.ownership_transferred' => t('أنت الآن مالك $g', 'You now own $g'),
      _ => title,
    };
  }

  /// Activity log lines (doc 13 activity vocabulary).
  String activityLine(String action, Map<String, dynamic> m, {required String actor, String? target}) {
    final tt = target ?? (m['title'] as String?) ?? '';
    return switch (action) {
      'group.created' => t('$actor أنشأ المجموعة', '$actor created the group'),
      'group.updated' => t('$actor عدّل إعدادات المجموعة', '$actor updated group settings'),
      'group.archived' => t('$actor أرشف المجموعة', '$actor archived the group'),
      'group.ownership_transferred' => t('$actor نقل ملكية المجموعة', '$actor transferred ownership'),
      'invite.regenerated' => t('$actor أعاد توليد رمز الدعوة', '$actor regenerated the invite code'),
      'invite.revoked' => t('$actor أوقف الدعوات', '$actor stopped invitations'),
      'join.requested' => t('$actor طلب الانضمام', '$actor requested to join'),
      'join.accepted' => t('$actor قبل عضواً جديداً', '$actor accepted a new member'),
      'join.rejected' => t('$actor رفض طلب انضمام', '$actor rejected a join request'),
      'member.removed' => t('$actor أزال عضواً', '$actor removed a member'),
      'member.left' => t('$actor غادر المجموعة', '$actor left the group'),
      'member.role_changed' => t('$actor غيّر دور عضو', '$actor changed a member\'s role'),
      'task.created' => t('$actor أنشأ «$tt»', '$actor created "$tt"'),
      'task.claimed' => t('$actor تولّى «$tt»', '$actor took "$tt"'),
      'task.started' => t('$actor بدأ «$tt»', '$actor started "$tt"'),
      'task.released' => t('$actor تنازل عن «$tt»', '$actor gave up "$tt"'),
      'task.reassigned' => t('$actor غيّر المسؤول عن «$tt»', '$actor reassigned "$tt"'),
      'task.unassigned' => t('«$tt» أصبحت مفتوحة', '"$tt" is open again'),
      'task.submitted' => t('$actor أنجز «$tt» وينتظر الاعتماد', '$actor finished "$tt", awaiting approval'),
      'task.completed' => t('$actor أنجز «$tt»', '$actor completed "$tt"'),
      'task.approved' => t('$actor اعتمد إنجاز «$tt»', '$actor approved "$tt"'),
      'task.rejected' => t('$actor أعاد «$tt»', '$actor sent back "$tt"'),
      'task.cancelled' => t('$actor ألغى «$tt»', '$actor cancelled "$tt"'),
      'task.reopened' => t('$actor أعاد فتح «$tt»', '$actor reopened "$tt"'),
      'task.updated' => t('$actor عدّل «$tt»', '$actor edited "$tt"'),
      'task.comment' => t('$actor علّق على «$tt»', '$actor commented on "$tt"'),
      'task.participant_added' => t('$actor أضاف مشاركاً في «$tt»', '$actor added a participant to "$tt"'),
      'task.participant_removed' => t('$actor أزال مشاركاً من «$tt»', '$actor removed a participant from "$tt"'),
      _ => '$actor · $action',
    };
  }
}
