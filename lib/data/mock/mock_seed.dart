import '../../core/utils/money.dart';
import '../../core/utils/quantity.dart';
import '../models/models.dart';
import 'mock_store.dart';

/// Sample accounts offered on the welcome screen, in display order.
const List<String> sampleUserIds = ['u_ali', 'u_hamza', 'u_usman', 'u_bilal'];

/// PROTOTYPE ONLY. Realistic sample data relative to today's date, so the
/// app always looks "current". Shows:
/// * a member who joined recently (Bilal) and is not part of older expenses;
/// * a former member (Fahad) whose expenses remain in the history;
/// * a voided duplicate, an edited expense, and fund vs personal payments;
/// * a pending join request (Zain) and a member without an account (Danish).
void seedSampleData(MockStore store) {
  final today = store.todayDate();
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);
  DateTime at(int n, int hour, [int minute = 0]) {
    final value = DateTime(today.year, today.month, today.day - n, hour, minute);
    final now = store.now();
    return value.isAfter(now) ? now : value;
  }

  void user(String id, String name, String email, {String? phone, bool registered = true}) {
    store.users[id] = AppUser(
      id: id,
      name: name,
      email: email,
      phone: phone,
      isRegistered: registered,
      hasCompletedProfile: registered,
      createdAt: daysAgo(60),
    );
  }

  user('u_ali', 'Ali Raza', 'ali.raza@gmail.com', phone: '+923001234567');
  user('u_hamza', 'Hamza Khan', 'hamza.khan@gmail.com', phone: '+923211234567');
  user('u_usman', 'Usman Tariq', 'usman.tariq@gmail.com');
  user('u_bilal', 'Bilal Ahmed', 'bilal.ahmed@gmail.com', phone: '+923451234567');
  user('u_fahad', 'Fahad Malik', 'fahad.malik@gmail.com');
  user('u_zain', 'Zain Abbas', 'zain.abbas@gmail.com');
  user('u_danish', 'Danish Iqbal', 'danish.iqbal@gmail.com', registered: false);

  void member(
    String groupId,
    String userId, {
    required int since,
    MemberRole role = MemberRole.member,
    MemberStatus status = MemberStatus.active,
    int? until,
    String? addedBy,
  }) {
    final u = store.users[userId]!;
    final id = 'm_${groupId}_$userId';
    store.members[id] = GroupMember(
      id: id,
      groupId: groupId,
      userId: userId,
      displayName: u.name,
      email: u.email,
      phone: u.phone,
      role: role,
      status: status,
      startDate: daysAgo(since),
      endDate: until == null ? null : daysAgo(until),
      addedByUserId: addedBy,
    );
  }

  var itemCounter = 0;
  ExpenseItem item(String name, int quantityMilli, int priceRupees) => ExpenseItem(
    id: 'item_${++itemCounter}',
    name: name,
    quantityMilli: quantityMilli,
    unitPricePaisa: Money.rupees(priceRupees),
  );
  int qty(int units) => Quantity.units(units);

  var expenseCounter = 0;
  void expense(
    String groupId, {
    required int day,
    required String title,
    required ExpenseCategory category,
    required String by,
    required List<String> split,
    String? paidBy,
    PaymentSource source = PaymentSource.personal,
    List<ExpenseItem> items = const [],
    int? amountRupees,
    String? notes,
    int hour = 19,
    int? editedDay,
    String? voidReason,
  }) {
    final id = 'e_${groupId}_${++expenseCounter}';
    final created = at(day, hour);
    store.expenses[id] = Expense(
      id: id,
      groupId: groupId,
      title: title,
      date: daysAgo(day),
      category: category,
      items: items,
      quickAmountPaisa: amountRupees == null ? null : Money.rupees(amountRupees),
      createdByUserId: by,
      paidByUserId: source == PaymentSource.groupFund ? null : (paidBy ?? by),
      paymentSource: source,
      splitAmongUserIds: split,
      notes: notes,
      status: voidReason == null ? ExpenseStatus.active : ExpenseStatus.voided,
      createdAt: created,
      editedAt: editedDay == null ? null : at(editedDay, 21, 15),
      voidedAt: voidReason == null ? null : at(day, hour + 1),
      voidReason: voidReason,
    );
  }

  // ---------------------------------------------------------------------------
  // Group 1: Gulberg Apartment 4B (Ali manages it)
  // ---------------------------------------------------------------------------
  const apt = 'g_apartment';
  store.groups[apt] = Group(
    id: apt,
    name: 'Gulberg Apartment 4B',
    description: 'Daily food, groceries and utilities. Rent is paid separately.',
    code: 'RMZ4B7',
    createdByUserId: 'u_ali',
    createdAt: at(40, 10),
  );
  member(apt, 'u_ali', since: 40, role: MemberRole.manager, addedBy: 'u_ali');
  member(apt, 'u_hamza', since: 40, addedBy: 'u_ali');
  member(apt, 'u_usman', since: 40, addedBy: 'u_ali');
  member(apt, 'u_fahad', since: 40, status: MemberStatus.left, until: 21, addedBy: 'u_ali');
  member(apt, 'u_bilal', since: 6, addedBy: 'u_hamza');

  const early = ['u_ali', 'u_hamza', 'u_usman', 'u_fahad'];
  const trio = ['u_ali', 'u_hamza', 'u_usman'];
  const four = ['u_ali', 'u_hamza', 'u_usman', 'u_bilal'];

  for (final id in trio) {
    store.contributions['c_${apt}_$id'] = Contribution(
      id: 'c_${apt}_$id',
      groupId: apt,
      memberUserId: id,
      amountPaisa: Money.rupees(5000),
      date: daysAgo(40),
      type: ContributionType.initial,
      recordedByUserId: 'u_ali',
      createdAt: at(40, 10),
    );
  }
  store.contributions['c_${apt}_bilal'] = Contribution(
    id: 'c_${apt}_bilal',
    groupId: apt,
    memberUserId: 'u_bilal',
    amountPaisa: Money.rupees(3000),
    date: daysAgo(6),
    type: ContributionType.topUp,
    recordedByUserId: 'u_bilal',
    createdAt: at(6, 12),
    note: 'Joining contribution',
  );

  expense(
    apt,
    day: 38,
    title: 'Monthly ration from Al-Fatah',
    category: ExpenseCategory.groceries,
    by: 'u_ali',
    source: PaymentSource.groupFund,
    split: early,
    hour: 18,
    items: [
      item('Atta (10 kg bag)', qty(1), 1450),
      item('Basmati rice (5 kg)', qty(1), 1650),
      item('Cooking oil (5 L)', qty(1), 2750),
      item('Sugar (kg)', qty(2), 160),
      item('Daal chana (kg)', qty(2), 320),
    ],
  );
  expense(
    apt,
    day: 35,
    title: 'Electricity bill (LESCO)',
    category: ExpenseCategory.bills,
    by: 'u_hamza',
    split: early,
    amountRupees: 8640,
    hour: 11,
    notes: 'September bill, paid at the bank.',
  );
  expense(
    apt,
    day: 33,
    title: 'Karahi night',
    category: ExpenseCategory.dinner,
    by: 'u_usman',
    split: early,
    items: [
      item('Chicken karahi (full)', qty(1), 1800),
      item('Naan', qty(8), 30),
      item('Raita', qty(2), 120),
      item('Cold drink (1.5 L)', qty(2), 220),
    ],
  );
  expense(
    apt,
    day: 30,
    title: 'Cleaning supplies',
    category: ExpenseCategory.household,
    by: 'u_fahad',
    split: early,
    hour: 16,
    items: [
      item('Surf Excel (1 kg)', qty(1), 650),
      item('Dishwash liquid', qty(2), 280),
      item('Phenyl', qty(1), 350),
      item('Garbage bags (pack)', qty(2), 150),
    ],
  );
  expense(
    apt,
    day: 28,
    title: 'Sunday halwa puri',
    category: ExpenseCategory.breakfast,
    by: 'u_hamza',
    split: early,
    hour: 10,
    items: [item('Halwa puri plate', qty(4), 250), item('Chana (extra)', qty(2), 150), item('Chai', qty(4), 60)],
  );
  expense(
    apt,
    day: 25,
    title: 'Internet (StormFiber)',
    category: ExpenseCategory.bills,
    by: 'u_ali',
    split: early,
    amountRupees: 4500,
    hour: 13,
  );
  expense(
    apt,
    day: 22,
    title: 'Rickshaw to Hafeez Centre',
    category: ExpenseCategory.transport,
    by: 'u_usman',
    paidBy: 'u_hamza',
    split: ['u_usman', 'u_hamza'],
    amountRupees: 600,
    hour: 17,
    notes: 'Hamza paid the driver; Usman added the entry.',
  );
  expense(
    apt,
    day: 20,
    title: 'Sabzi and fruit',
    category: ExpenseCategory.groceries,
    by: 'u_hamza',
    source: PaymentSource.groupFund,
    split: trio,
    hour: 18,
    items: [
      item('Tomatoes (kg)', qty(2), 180),
      item('Onions (kg)', qty(3), 140),
      item('Potatoes (kg)', qty(3), 110),
      item('Bananas (dozen)', qty(2), 220),
      item('Yogurt (kg)', 1500, 240),
    ],
  );
  expense(
    apt,
    day: 18,
    title: 'Pizza order',
    category: ExpenseCategory.dinner,
    by: 'u_usman',
    split: trio,
    amountRupees: 4468,
    hour: 21,
    voidReason: 'Entered twice. See "Pizza night" on the same day.',
  );
  expense(
    apt,
    day: 18,
    title: 'Pizza night',
    category: ExpenseCategory.dinner,
    by: 'u_usman',
    split: trio,
    hour: 21,
    items: [
      item('Large pizza', qty(2), 1899),
      item('Garlic bread', qty(1), 450),
      item('Cold drink (1.5 L)', qty(1), 220),
    ],
  );
  expense(
    apt,
    day: 14,
    title: 'Gas bill (SNGPL)',
    category: ExpenseCategory.bills,
    by: 'u_ali',
    source: PaymentSource.groupFund,
    split: trio,
    amountRupees: 2350,
    hour: 12,
  );
  expense(
    apt,
    day: 10,
    title: 'Biryani lunch',
    category: ExpenseCategory.lunch,
    by: 'u_hamza',
    split: trio,
    hour: 14,
    editedDay: 9,
    notes: 'Corrected the raita quantity.',
    items: [item('Chicken biryani', qty(3), 420), item('Raita', qty(3), 60)],
  );
  expense(
    apt,
    day: 5,
    title: 'Weekly groceries',
    category: ExpenseCategory.groceries,
    by: 'u_bilal',
    split: four,
    hour: 19,
    items: [
      item('Milk (1 L)', qty(7), 220),
      item('Eggs (dozen)', qty(2), 360),
      item('Bread', qty(3), 180),
      item('Tapal tea (950 g)', qty(1), 1350),
    ],
  );
  expense(
    apt,
    day: 3,
    title: 'Water cans (19 L)',
    category: ExpenseCategory.household,
    by: 'u_usman',
    source: PaymentSource.groupFund,
    split: four,
    hour: 11,
    items: [item('Water can refill', qty(4), 180)],
  );
  expense(
    apt,
    day: 2,
    title: 'Daal chawal dinner',
    category: ExpenseCategory.dinner,
    by: 'u_ali',
    split: four,
    amountRupees: 950,
    hour: 20,
  );
  expense(
    apt,
    day: 1,
    title: 'Careem to the grocery store',
    category: ExpenseCategory.transport,
    by: 'u_bilal',
    split: ['u_bilal', 'u_ali'],
    amountRupees: 480,
    hour: 17,
  );
  expense(
    apt,
    day: 0,
    title: 'Paratha and chai',
    category: ExpenseCategory.breakfast,
    by: 'u_hamza',
    split: four,
    hour: 9,
    items: [item('Aloo paratha', qty(4), 120), item('Chai', qty(4), 70)],
  );

  store.joinRequests['r_zain'] = JoinRequest(
    id: 'r_zain',
    groupId: apt,
    groupName: 'Gulberg Apartment 4B',
    userId: 'u_zain',
    name: 'Zain Abbas',
    email: 'zain.abbas@gmail.com',
    status: JoinRequestStatus.pending,
    requestedAt: at(0, 8, 30),
  );

  // ---------------------------------------------------------------------------
  // Group 2: Hostel Room 12 (Hamza manages it; Ali is a regular member)
  // ---------------------------------------------------------------------------
  const hostel = 'g_hostel';
  store.groups[hostel] = Group(
    id: hostel,
    name: 'Hostel Room 12, Johar Town',
    description: 'Mess bills and room supplies.',
    code: 'HST12Q',
    createdByUserId: 'u_hamza',
    createdAt: at(25, 9),
  );
  member(hostel, 'u_hamza', since: 25, role: MemberRole.manager, addedBy: 'u_hamza');
  member(hostel, 'u_ali', since: 25, addedBy: 'u_hamza');
  member(hostel, 'u_danish', since: 25, addedBy: 'u_hamza');

  const room = ['u_hamza', 'u_ali', 'u_danish'];
  expense(
    hostel,
    day: 20,
    title: 'Mess bill, week 1',
    category: ExpenseCategory.bills,
    by: 'u_hamza',
    split: room,
    amountRupees: 3600,
    hour: 12,
  );
  expense(
    hostel,
    day: 13,
    title: 'Chai and biscuits',
    category: ExpenseCategory.breakfast,
    by: 'u_ali',
    split: room,
    hour: 22,
    items: [item('Chai', qty(9), 50), item('Biscuits (pack)', qty(3), 60)],
  );
  expense(
    hostel,
    day: 6,
    title: 'Mess bill, week 3',
    category: ExpenseCategory.bills,
    by: 'u_hamza',
    split: room,
    amountRupees: 3600,
    hour: 12,
  );
  expense(
    hostel,
    day: 2,
    title: 'Laundry',
    category: ExpenseCategory.household,
    by: 'u_ali',
    paidBy: 'u_danish',
    split: room,
    amountRupees: 900,
    hour: 18,
    notes: 'Danish paid the dhobi.',
  );
}
