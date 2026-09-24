import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DebtManagerApp());
}

class DebtManagerApp extends StatelessWidget {
  const DebtManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Капитал',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF124A3B),
          brightness: Brightness.light,
          surface: const Color(0xFFF7F4ED),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F4ED),
        useMaterial3: true,
        fontFamily: 'Georgia',
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const DebtHomePage(),
    );
  }
}

class DebtHomePage extends StatefulWidget {
  const DebtHomePage({super.key});

  @override
  State<DebtHomePage> createState() => _DebtHomePageState();
}

class _DebtHomePageState extends State<DebtHomePage> {
  final DebtRepository _repository = DebtRepository();
  List<Loan> _loans = [];
  List<LoanRequest> _requests = [];
  List<DebtTariff> _tariffs = [];
  Map<String, String> _debtorPhotos = {};
  int _section = 1;
  DebtorSortMode _debtorSortMode = DebtorSortMode.dueDate;
  bool _showDebtorTotals = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repository.load();
    if (!mounted) return;
    setState(() {
      _loans = data.loans;
      _requests = data.requests;
      _tariffs = data.tariffs;
      _debtorPhotos = data.debtorPhotos;
      _debtorSortMode = data.debtorSortMode;
      _showDebtorTotals = data.showDebtorTotals;
      _loading = false;
    });
  }

  Future<void> _save() => _repository.save(
    _loans,
    _requests,
    _tariffs,
    _showDebtorTotals,
    _debtorPhotos,
    _debtorSortMode,
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = switch (_section) {
      0 => DashboardView(
        loans: _loans,
        requests: _requests,
        onOpenLoan: _openLoan,
        onOpenRequests: () => setState(() => _section = 3),
      ),
      1 => LoansView(
        loans: _loans,
        showTotals: _showDebtorTotals,
        debtorPhotos: _debtorPhotos,
        sortMode: _debtorSortMode,
        onSortModeChanged: _setDebtorSortMode,
        onOpenDebtor: _openDebtor,
        onAddLoan: _addLoan,
      ),
      2 => CalendarView(
        loans: _loans,
        onOpenLoan: _openLoan,
        onScheduleReturn: _scheduleReturn,
      ),
      3 => RequestsView(
        requests: _requests,
        onAddRequest: _addRequest,
        onApprove: _approveRequest,
        onReject: _rejectRequest,
        onDelete: _deleteRequest,
      ),
      _ => TariffsView(
        tariffs: _tariffs,
        showDebtorTotals: _showDebtorTotals,
        onShowDebtorTotalsChanged: _setShowDebtorTotals,
        onEditTariff: _editTariff,
      ),
    };

    return Scaffold(
      drawer: wide
          ? null
          : AppDrawer(
              selectedIndex: _section,
              pendingCount: _requests
                  .where((item) => item.status == 'pending')
                  .length,
              onSelected: (value) {
                Navigator.of(context).pop();
                setState(() => _section = value);
              },
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              AppNavigationRail(
                selectedIndex: _section,
                onSelected: (value) => setState(() => _section = value),
                pendingCount: _requests
                    .where((item) => item.status == 'pending')
                    .length,
              ),
            Expanded(
              child: Builder(
                builder: (context) => Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 30 : 16, 18, 16, 12),
                  child: Column(
                    children: [
                      if (!wide)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton.filledTonal(
                            tooltip: 'Меню',
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            icon: const Icon(Icons.menu),
                          ),
                        ),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide || _section == 4
          ? null
          : NavigationBar(
              selectedIndex: _section,
              onDestinationSelected: (value) =>
                  setState(() => _section = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Обзор',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Должники',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Календарь',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inbox_outlined),
                  selectedIcon: Icon(Icons.inbox),
                  label: 'Заявки',
                ),
              ],
            ),
    );
  }

  Future<void> _openLoan(Loan loan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanDetailsPage(
          loan: loan,
          onEditLoan: _editLoan,
          onAddPayment: _addPayment,
          onAddLoanForDebtor: _addLoanForDebtor,
          onArchiveLoan: _archiveLoan,
          onDeleteLoan: _deleteLoan,
          onCloseEarly: _closeLoanEarly,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openDebtor(DebtorAccount debtor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DebtorProfilePage(
          debtorName: debtor.name,
          showTotals: _showDebtorTotals,
          photoPath: debtorPhotoPath(_debtorPhotos, debtor.name),
          loansProvider: () => _loans,
          onOpenLoan: _openLoan,
          onAddLoanForDebtor: _addLoanForDebtorName,
          onUpdatePhoto: _setDebtorPhoto,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _addLoan() async {
    final loan = await showDialog<Loan>(
      context: context,
      builder: (_) => CreateLoanDialog(
        tariffs: _tariffs,
        debtors: knownDebtors(_loans),
        recentDebtors: recentDebtors(_loans),
      ),
    );
    if (loan == null) return;
    final stored = await _repository.createLoan(loan);
    setState(() => _loans.insert(0, stored));
    await _save();
  }

  Future<void> _addLoanForDebtor(Loan source) async {
    await _addLoanForDebtorName(source.debtorName);
  }

  Future<void> _addLoanForDebtorName(String debtorName) async {
    final loan = await showDialog<Loan>(
      context: context,
      builder: (_) => CreateLoanDialog(
        tariffs: _tariffs,
        debtors: knownDebtors(_loans),
        recentDebtors: recentDebtors(_loans),
        initialDebtorName: debtorName,
      ),
    );
    if (loan == null) return;
    final stored = await _repository.createLoan(loan);
    setState(() => _loans.insert(0, stored));
    await _save();
  }

  Future<Loan?> _editLoan(Loan loan) async {
    final updated = await showDialog<Loan>(
      context: context,
      builder: (_) => EditLoanDialog(loan: loan),
    );
    if (updated == null) return null;
    final index = _loans.indexWhere((item) => item.id == loan.id);
    if (index == -1) return null;
    setState(() => _loans[index] = updated);
    await _save();
    return updated;
  }

  Future<Loan?> _addPayment(Loan loan) async {
    final payment = await showDialog<LoanPaymentDraft>(
      context: context,
      builder: (_) => AddPaymentDialog(loan: loan),
    );
    if (payment == null) return null;
    final index = _loans.indexWhere((item) => item.id == loan.id);
    if (index == -1) return null;
    final updated = loan.copyWith(
      paidAmount: loan.paidAmount + payment.amount,
      note: payment.note.isEmpty ? loan.note : payment.note,
    );
    setState(() => _loans[index] = updated);
    await _save();
    return updated;
  }

  Future<Loan?> _archiveLoan(Loan loan) async {
    final index = _loans.indexWhere((item) => item.id == loan.id);
    if (index == -1) return null;
    final updated = loan.copyWith(archivedAt: DateTime.now());
    setState(() => _loans[index] = updated);
    await _save();
    return updated;
  }

  Future<bool> _deleteLoan(Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить долг?'),
        content: Text(
          '${loan.debtorName}: ${money(loan.remainingDue)}. '
          'Запись исчезнет из списка.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    setState(() => _loans.removeWhere((item) => item.id == loan.id));
    await _save();
    return true;
  }

  Future<void> _addRequest() async {
    final request = await showDialog<LoanRequest>(
      context: context,
      builder: (_) => CreateRequestDialog(tariffs: _tariffs),
    );
    if (request == null) return;
    setState(() => _requests.insert(0, request));
    await _save();
  }

  Future<void> _scheduleReturn(
    Loan loan,
    DateTime dueAt,
    double amount,
    String note,
  ) async {
    final index = _loans.indexWhere((item) => item.id == loan.id);
    if (index == -1) return;
    setState(() {
      _loans[index] = loan.copyWith(
        dueAt: dateOnly(dueAt),
        expectedReturnAmount: amount,
        note: note.isEmpty ? loan.note : note,
      );
    });
    await _save();
  }

  Future<Loan?> _closeLoanEarly(Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Закрыть долг досрочно?'),
        content: Text(
          '${loan.debtorName} должен внести ${money(loan.remainingDue)}. '
          'После закрытия начисления остановятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Закрыть долг'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    final closedLoan = await _repository.closeLoan(loan);
    final index = _loans.indexWhere((item) => item.id == loan.id);
    var stored = closedLoan;
    setState(() {
      if (index == -1) {
        loan.closedAt = dateOnly(DateTime.now());
        stored = loan;
      } else {
        _loans[index] = closedLoan;
      }
    });
    await _save();
    return stored;
  }

  Future<void> _approveRequest(LoanRequest request) async {
    final data = await _repository.approveRequest(request);
    setState(() {
      _loans = data.loans;
      _requests = data.requests;
      _tariffs = data.tariffs;
      _showDebtorTotals = data.showDebtorTotals;
      _debtorSortMode = data.debtorSortMode;
    });
    await _save();
  }

  Future<void> _rejectRequest(LoanRequest request) async {
    final data = await _repository.rejectRequest(request);
    setState(() {
      _loans = data.loans;
      _requests = data.requests;
      _tariffs = data.tariffs;
      _showDebtorTotals = data.showDebtorTotals;
      _debtorSortMode = data.debtorSortMode;
    });
    await _save();
  }

  Future<void> _deleteRequest(LoanRequest request) async {
    setState(() => _requests.removeWhere((item) => item.id == request.id));
    await _save();
  }

  Future<void> _setShowDebtorTotals(bool value) async {
    setState(() => _showDebtorTotals = value);
    await _save();
  }

  Future<void> _setDebtorPhoto(String debtorName, String? path) async {
    final key = debtorKey(debtorName);
    setState(() {
      if (path == null || path.isEmpty) {
        _debtorPhotos.remove(key);
      } else {
        _debtorPhotos[key] = path;
      }
    });
    await _save();
  }

  Future<void> _setDebtorSortMode(DebtorSortMode mode) async {
    setState(() => _debtorSortMode = mode);
    await _save();
  }

  Future<void> _editTariff(DebtTariff tariff) async {
    final updated = await showDialog<DebtTariff>(
      context: context,
      builder: (_) => EditTariffDialog(tariff: tariff),
    );
    if (updated == null) return;
    final stored = await _repository.updateTariff(updated);
    final data = await _repository.load();
    setState(() {
      _tariffs = data.tariffs
          .map((item) => item.id == stored.id ? stored : item)
          .toList();
      _loans = data.loans;
      _requests = data.requests;
      _showDebtorTotals = data.showDebtorTotals;
      _debtorSortMode = data.debtorSortMode;
    });
  }
}

class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.pendingCount,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      color: const Color(0xFF123D34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'КАПИТАЛ',
                  style: TextStyle(
                    color: Color(0xFFF1C56B),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'личный учет займов',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Обзор',
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Должники',
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          _NavItem(
            icon: Icons.calendar_month_outlined,
            label: 'Календарь',
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
          _NavItem(
            icon: Icons.inbox_outlined,
            label: 'Заявки',
            badge: pendingCount,
            selected: selectedIndex == 3,
            onTap: () => onSelected(3),
          ),
          _NavItem(
            icon: Icons.tune_outlined,
            label: 'Настройки',
            selected: selectedIndex == 4,
            onTap: () => onSelected(4),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Данные синхронизируются с backend',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.selectedIndex,
    required this.pendingCount,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF123D34),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'КАПИТАЛ',
                      style: TextStyle(
                        color: Color(0xFFF1C56B),
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'личный учет займов',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _NavItem(
                icon: Icons.dashboard_outlined,
                label: 'Обзор',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _NavItem(
                icon: Icons.people_outline,
                label: 'Должники',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              _NavItem(
                icon: Icons.calendar_month_outlined,
                label: 'Календарь',
                selected: selectedIndex == 2,
                onTap: () => onSelected(2),
              ),
              _NavItem(
                icon: Icons.inbox_outlined,
                label: 'Заявки',
                badge: pendingCount,
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
              const Divider(color: Colors.white24, height: 30),
              _NavItem(
                icon: Icons.tune_outlined,
                label: 'Настройки',
                selected: selectedIndex == 4,
                onTap: () => onSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? Colors.white12 : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: selected ? Colors.white : Colors.white60),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (badge > 0)
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: const Color(0xFFF1C56B),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Color(0xFF123D34),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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

class DashboardView extends StatelessWidget {
  const DashboardView({
    required this.loans,
    required this.requests,
    required this.onOpenLoan,
    required this.onOpenRequests,
    super.key,
  });

  final List<Loan> loans;
  final List<LoanRequest> requests;
  final ValueChanged<Loan> onOpenLoan;
  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context) {
    final active = loans.where((item) => item.isActive).toList();
    final pending = requests.where((item) => item.status == 'pending').toList();
    final principal = active.fold<double>(
      0,
      (sum, loan) => sum + loan.principal,
    );
    final interest = active.fold<double>(0, (sum, loan) => sum + loan.interest);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200
        ? 4
        : width >= 650
        ? 2
        : 1;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: todayLabel(),
            title: 'Обзор портфеля',
            subtitle: 'Суммы, сроки и заявки в одном месте.',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 24),
          sliver: SliverGrid.count(
            crossAxisCount: columns,
            childAspectRatio: columns == 1 ? 2.7 : 1.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              MetricCard(
                label: 'ВЫДАНО В РАБОТУ',
                value: money(principal),
                icon: Icons.account_balance_wallet_outlined,
                tone: const Color(0xFF123D34),
              ),
              MetricCard(
                label: 'НАЧИСЛЕНО %',
                value: money(interest),
                icon: Icons.trending_up,
                tone: const Color(0xFF9A5B2C),
              ),
              MetricCard(
                label: 'АКТИВНЫЕ ДОЛГИ',
                value: '${active.length}',
                icon: Icons.people_outline,
                tone: const Color(0xFF3F6681),
              ),
              MetricCard(
                label: 'НОВЫЕ ЗАЯВКИ',
                value: '${pending.length}',
                icon: Icons.mark_email_unread_outlined,
                tone: const Color(0xFF8B4C4C),
                onTap: onOpenRequests,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 30, bottom: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ближайшие платежи',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${active.length} активных',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        if (active.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyCard(text: 'Активных долгов пока нет'),
          )
        else
          SliverList.separated(
            itemCount: active.length > 4 ? 4 : active.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final sorted = [...active]
                ..sort((a, b) => compareNullableDates(a.dueAt, b.dueAt));
              return LoanTile(loan: sorted[index], onTap: onOpenLoan);
            },
          ),
      ],
    );
  }
}

class LoansView extends StatelessWidget {
  const LoansView({
    required this.loans,
    required this.showTotals,
    required this.debtorPhotos,
    required this.sortMode,
    required this.onSortModeChanged,
    required this.onOpenDebtor,
    required this.onAddLoan,
    super.key,
  });

  final List<Loan> loans;
  final bool showTotals;
  final Map<String, String> debtorPhotos;
  final DebtorSortMode sortMode;
  final ValueChanged<DebtorSortMode> onSortModeChanged;
  final ValueChanged<DebtorAccount> onOpenDebtor;
  final VoidCallback onAddLoan;

  @override
  Widget build(BuildContext context) {
    final active = sortDebtorAccounts(
      debtorAccounts(loans.where((item) => item.isActive)),
      sortMode,
    );
    final closed = sortDebtorAccounts(
      debtorAccounts(
        loans.where((item) => !item.isActive && item.archivedAt == null),
      ),
      sortMode,
    );
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: '${active.length} активных должников',
            title: 'Должники',
            subtitle: 'Один человек — один профиль со всеми займами внутри.',
            action: FilledButton.icon(
              onPressed: onAddLoan,
              icon: const Icon(Icons.add),
              label: const Text('Новый займ'),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<DebtorSortMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: DebtorSortMode.dueDate,
                    icon: Icon(Icons.event_outlined),
                    label: Text('Дата'),
                  ),
                  ButtonSegment(
                    value: DebtorSortMode.alphabet,
                    icon: Icon(Icons.sort_by_alpha),
                    label: Text('А-Я'),
                  ),
                  ButtonSegment(
                    value: DebtorSortMode.debt,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Долг'),
                  ),
                ],
                selected: {sortMode},
                onSelectionChanged: (values) => onSortModeChanged(values.first),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionLabel(text: 'АКТИВНЫЕ', count: active.length),
        ),
        if (active.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyCard(text: 'Нет активных долгов'),
          )
        else
          SliverList.separated(
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => DebtorTile(
              debtor: active[index],
              showTotal: showTotals,
              photoPath: debtorPhotoPath(debtorPhotos, active[index].name),
              onTap: onOpenDebtor,
            ),
          ),
        SliverToBoxAdapter(
          child: SectionLabel(text: 'ЗАКРЫТЫЕ', count: closed.length),
        ),
        SliverList.separated(
          itemCount: closed.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) => DebtorTile(
            debtor: closed[index],
            showTotal: showTotals,
            photoPath: debtorPhotoPath(debtorPhotos, closed[index].name),
            onTap: onOpenDebtor,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}

enum DebtorSortMode { dueDate, alphabet, debt }

DebtorSortMode debtorSortModeFromJson(Object? value) {
  final raw = value?.toString();
  for (final mode in DebtorSortMode.values) {
    if (mode.name == raw) return mode;
  }
  return DebtorSortMode.dueDate;
}

class DebtorAccount {
  DebtorAccount({required this.name, required List<Loan> loans})
    : loans = [...loans]
        ..sort((a, b) {
          final left = a.dueAt;
          final right = b.dueAt;
          if (left == null && right == null) {
            return b.issuedAt.compareTo(a.issuedAt);
          }
          if (left == null) return 1;
          if (right == null) return -1;
          return left.compareTo(right);
        });

  final String name;
  final List<Loan> loans;

  List<Loan> get activeLoans => loans.where((loan) => loan.isActive).toList();
  int get loanCount => loans.length;
  double get totalRemaining =>
      activeLoans.fold<double>(0, (sum, loan) => sum + loan.remainingDue);
  DateTime? get nearestDueAt {
    DateTime? nearest;
    for (final loan in activeLoans) {
      final dueAt = loan.dueAt;
      if (dueAt == null) continue;
      if (nearest == null || dueAt.isBefore(nearest)) nearest = dueAt;
    }
    return nearest;
  }

  bool get hasOpenEndedLoan => activeLoans.any((loan) => loan.dueAt == null);
}

List<DebtorAccount> debtorAccounts(Iterable<Loan> loans) {
  final grouped = <String, List<Loan>>{};
  final displayNames = <String, String>{};
  for (final loan in loans) {
    final name = loan.debtorName.trim();
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    grouped.putIfAbsent(key, () => []).add(loan);
    displayNames.putIfAbsent(key, () => name);
  }
  final accounts = grouped.entries
      .map(
        (entry) => DebtorAccount(
          name: displayNames[entry.key] ?? entry.key,
          loans: entry.value,
        ),
      )
      .toList();
  accounts.sort((a, b) {
    final dueCompare = compareNullableDates(a.nearestDueAt, b.nearestDueAt);
    if (dueCompare != 0) return dueCompare;
    return b.totalRemaining.compareTo(a.totalRemaining);
  });
  return accounts;
}

List<DebtorAccount> sortDebtorAccounts(
  List<DebtorAccount> accounts,
  DebtorSortMode mode,
) {
  final sorted = [...accounts];
  sorted.sort((a, b) {
    return switch (mode) {
      DebtorSortMode.dueDate => compareNullableDates(
        a.nearestDueAt,
        b.nearestDueAt,
      ),
      DebtorSortMode.alphabet => debtorKey(a.name).compareTo(debtorKey(b.name)),
      DebtorSortMode.debt => b.totalRemaining.compareTo(a.totalRemaining),
    };
  });
  if (mode != DebtorSortMode.alphabet) {
    sorted.sort((a, b) {
      final primary = switch (mode) {
        DebtorSortMode.dueDate => compareNullableDates(
          a.nearestDueAt,
          b.nearestDueAt,
        ),
        DebtorSortMode.debt => b.totalRemaining.compareTo(a.totalRemaining),
        DebtorSortMode.alphabet => 0,
      };
      if (primary != 0) return primary;
      return debtorKey(a.name).compareTo(debtorKey(b.name));
    });
  }
  return sorted;
}

class DebtorAvatar extends StatelessWidget {
  const DebtorAvatar({
    required this.name,
    required this.photoPath,
    required this.radius,
    super.key,
  });

  final String name;
  final String? photoPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final hasPhoto = path != null && File(path).existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDCEAE3),
      backgroundImage: hasPhoto ? FileImage(File(path)) : null,
      child: hasPhoto
          ? null
          : Text(
              initials(name),
              style: const TextStyle(
                color: Color(0xFF123D34),
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class DebtorTile extends StatelessWidget {
  const DebtorTile({
    required this.debtor,
    required this.showTotal,
    required this.photoPath,
    required this.onTap,
    super.key,
  });

  final DebtorAccount debtor;
  final bool showTotal;
  final String? photoPath;
  final ValueChanged<DebtorAccount> onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final dueLabel = debtor.nearestDueAt == null
        ? 'без даты'
        : dueCountdownLabel(debtor.nearestDueAt!);
    return Card(
      child: InkWell(
        onTap: () => onTap(debtor),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: Row(
            children: [
              DebtorAvatar(
                name: debtor.name,
                photoPath: photoPath,
                radius: compact ? 22 : 25,
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debtor.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${debtor.loanCount} ${loanWord(debtor.loanCount)} • $dueLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    if (debtor.hasOpenEndedLoan && debtor.nearestDueAt != null)
                      const Text(
                        'есть займ без даты возврата',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (showTotal)
                SizedBox(
                  width: compact ? 92 : 108,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      money(debtor.totalRemaining),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              const Icon(Icons.chevron_right, color: Colors.black38, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class DebtorProfilePage extends StatefulWidget {
  const DebtorProfilePage({
    required this.debtorName,
    required this.showTotals,
    required this.photoPath,
    required this.loansProvider,
    required this.onOpenLoan,
    required this.onAddLoanForDebtor,
    required this.onUpdatePhoto,
    super.key,
  });

  final String debtorName;
  final bool showTotals;
  final String? photoPath;
  final List<Loan> Function() loansProvider;
  final Future<void> Function(Loan) onOpenLoan;
  final Future<void> Function(String) onAddLoanForDebtor;
  final Future<void> Function(String, String?) onUpdatePhoto;

  @override
  State<DebtorProfilePage> createState() => _DebtorProfilePageState();
}

class _DebtorProfilePageState extends State<DebtorProfilePage> {
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.photoPath;
  }

  List<Loan> get _loans =>
      widget
          .loansProvider()
          .where((loan) => sameDebtor(loan.debtorName, widget.debtorName))
          .toList()
        ..sort((a, b) {
          final dueCompare = compareNullableDates(a.dueAt, b.dueAt);
          if (dueCompare != 0) return dueCompare;
          return b.issuedAt.compareTo(a.issuedAt);
        });

  @override
  Widget build(BuildContext context) {
    final loans = _loans;
    final active = loans.where((loan) => loan.isActive).toList();
    final total = active.fold<double>(
      0,
      (sum, loan) => sum + loan.remainingDue,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.debtorName),
        backgroundColor: const Color(0xFFF7F4ED),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            PageHeader(
              eyebrow: '${active.length} активных займов',
              title: widget.debtorName,
              subtitle: widget.showTotals
                  ? 'Общий остаток: ${money(total)}'
                  : 'Все займы этого человека в одном профиле.',
              action: FilledButton.icon(
                onPressed: () async {
                  await widget.onAddLoanForDebtor(widget.debtorName);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add),
                label: const Text('Еще займ'),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    DebtorAvatar(
                      name: widget.debtorName,
                      photoPath: _photoPath,
                      radius: 38,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Фото должника',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _photoPath == null
                                ? 'Пока стоят инициалы'
                                : 'Показывается в списке должников',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Выбрать фото',
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                        ),
                        if (_photoPath != null)
                          IconButton(
                            tooltip: 'Убрать фото',
                            onPressed: _removePhoto,
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (loans.isEmpty)
              const EmptyCard(text: 'Займов у должника пока нет')
            else
              ...loans.map(
                (loan) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LoanTile(
                    loan: loan,
                    onTap: (item) async {
                      await widget.onOpenLoan(item);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 82,
    );
    if (image == null) return;
    final savedPath = await saveDebtorPhoto(widget.debtorName, image.path);
    await widget.onUpdatePhoto(widget.debtorName, savedPath);
    if (mounted) setState(() => _photoPath = savedPath);
  }

  Future<void> _removePhoto() async {
    await widget.onUpdatePhoto(widget.debtorName, null);
    if (mounted) setState(() => _photoPath = null);
  }
}

class RequestsView extends StatelessWidget {
  const RequestsView({
    required this.requests,
    required this.onAddRequest,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
    super.key,
  });

  final List<LoanRequest> requests;
  final VoidCallback onAddRequest;
  final ValueChanged<LoanRequest> onApprove;
  final ValueChanged<LoanRequest> onReject;
  final ValueChanged<LoanRequest> onDelete;

  @override
  Widget build(BuildContext context) {
    final pending = requests.where((item) => item.status == 'pending').toList();
    final history = requests.where((item) => item.status != 'pending').toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'ВХОДЯЩИЕ ОБРАЩЕНИЯ',
            title: 'Заявки на займ',
            subtitle:
                'Записывай запросы, пока ищешь деньги или принимаешь решение.',
            action: FilledButton.icon(
              onPressed: onAddRequest,
              icon: const Icon(Icons.add),
              label: const Text('Новая заявка'),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionLabel(text: 'ОЖИДАЮТ РЕШЕНИЯ', count: pending.length),
        ),
        if (pending.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyCard(text: 'Новых заявок сейчас нет'),
          )
        else
          SliverList.separated(
            itemCount: pending.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => RequestTile(
              request: pending[index],
              onApprove: () => onApprove(pending[index]),
              onReject: () => onReject(pending[index]),
              onDelete: () => onDelete(pending[index]),
            ),
          ),
        SliverToBoxAdapter(
          child: SectionLabel(text: 'ИСТОРИЯ', count: history.length),
        ),
        SliverList.separated(
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) => RequestTile(
            request: history[index],
            onDelete: () => onDelete(history[index]),
          ),
        ),
      ],
    );
  }
}

class CalendarView extends StatefulWidget {
  const CalendarView({
    required this.loans,
    required this.onOpenLoan,
    required this.onScheduleReturn,
    super.key,
  });

  final List<Loan> loans;
  final ValueChanged<Loan> onOpenLoan;
  final Future<void> Function(Loan, DateTime, double, String) onScheduleReturn;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.loans.where((item) => item.isActive).toList();
    final datedActive = active.where((loan) => loan.dueAt != null).toList();
    final monthDays = daysInMonth(_month);
    final monthExpected = monthDays.fold<double>(
      0,
      (sum, day) =>
          sum +
          datedActive
              .where((loan) => loan.isDueOn(day))
              .fold<double>(0, (daily, loan) => daily + loan.remainingDue),
    );
    final monthDue =
        datedActive
            .where(
              (loan) =>
                  loan.dueAt!.year == _month.year &&
                  loan.dueAt!.month == _month.month,
            )
            .toList()
          ..sort((a, b) => compareNullableDates(a.dueAt, b.dueAt));

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'ОЖИДАЕМЫЕ ВОЗВРАТЫ',
            title: 'Календарь',
            subtitle: 'Кто и сколько должен вернуть по датам.',
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _month = DateTime(_month.year, _month.month - 1);
                          }),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                monthLabel(_month),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'ожидается: ${money(monthExpected)}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _month = DateTime(_month.year, _month.month + 1);
                          }),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        _WeekDay('ПН'),
                        _WeekDay('ВТ'),
                        _WeekDay('СР'),
                        _WeekDay('ЧТ'),
                        _WeekDay('ПТ'),
                        _WeekDay('СБ'),
                        _WeekDay('ВС'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    PortfolioCalendarGrid(
                      month: _month,
                      loans: datedActive,
                      onOpenLoan: widget.onOpenLoan,
                      onScheduleReturn: widget.onScheduleReturn,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionLabel(
            text: 'ОЖИДАЕТСЯ В ЭТОМ МЕСЯЦЕ',
            count: monthDue.length,
          ),
        ),
        if (monthDue.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyCard(text: 'На этот месяц возвратов нет'),
          )
        else
          SliverList.separated(
            itemCount: monthDue.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) =>
                LoanTile(loan: monthDue[index], onTap: widget.onOpenLoan),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}

class PortfolioCalendarGrid extends StatelessWidget {
  const PortfolioCalendarGrid({
    required this.month,
    required this.loans,
    required this.onOpenLoan,
    required this.onScheduleReturn,
    super.key,
  });

  final DateTime month;
  final List<Loan> loans;
  final ValueChanged<Loan> onOpenLoan;
  final Future<void> Function(Loan, DateTime, double, String) onScheduleReturn;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: leading + count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.88,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (_, index) {
        if (index < leading) return const SizedBox.shrink();
        final day = DateTime(month.year, month.month, index - leading + 1);
        final dayLoans = loans.where((loan) => loan.isDueOn(day)).toList();
        final active = dayLoans.isNotEmpty;
        final tone = active
            ? debtorColor(dayLoans.first.debtorName)
            : const Color(0xFFF3F1EB);

        return InkWell(
          onTap: () => showModalBottomSheet<void>(
            useSafeArea: true,
            context: context,
            isScrollControlled: true,
            builder: (_) => DayReturnsSheet(
              day: day,
              loans: dayLoans,
              availableLoans: loans,
              onOpenLoan: onOpenLoan,
              onScheduleReturn: onScheduleReturn,
            ),
          ),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(
              color: active ? tone.withValues(alpha: 0.16) : tone,
              borderRadius: BorderRadius.circular(9),
              border: active ? Border.all(color: tone, width: 1.5) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (active) ...[
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: dayLoans
                          .take(3)
                          .map(
                            (loan) => Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: debtorColor(loan.debtorName),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (dayLoans.length > 3)
                    Text(
                      '+${dayLoans.length - 3}',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class DayReturnsSheet extends StatelessWidget {
  const DayReturnsSheet({
    required this.day,
    required this.loans,
    required this.availableLoans,
    required this.onOpenLoan,
    required this.onScheduleReturn,
    super.key,
  });

  final DateTime day;
  final List<Loan> loans;
  final List<Loan> availableLoans;
  final ValueChanged<Loan> onOpenLoan;
  final Future<void> Function(Loan, DateTime, double, String) onScheduleReturn;

  @override
  Widget build(BuildContext context) {
    final sorted = [...loans]
      ..sort((a, b) => b.remainingDue.compareTo(a.remainingDue));
    final total = sorted.fold<double>(
      0,
      (sum, loan) => sum + loan.remainingDue,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                longDate(day),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sorted.isEmpty
                    ? 'На этот день выплат пока нет.'
                    : 'Ожидается ${money(total)} • ${sorted.length} возврат.',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: sorted.isEmpty
                    ? const EmptyCard(
                        text: 'Нажми ниже и назначь возврат вручную',
                      )
                    : ListView.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final loan = sorted[index];
                          final tone = debtorColor(loan.debtorName);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.pop(context);
                              onOpenLoan(loan);
                            },
                            leading: CircleAvatar(
                              backgroundColor: tone.withValues(alpha: 0.18),
                              child: Text(
                                initials(loan.debtorName),
                                style: const TextStyle(
                                  color: Color(0xFF123D34),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              loan.debtorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(loan.conditionLabel),
                            trailing: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  money(loan.remainingDue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF123D34),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Изменить выплату',
                                  onPressed: () => _editReturn(context, loan),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: availableLoans.isEmpty
                      ? null
                      : () => _editReturn(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить выплату'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editReturn(BuildContext context, Loan? loan) async {
    final result = await showDialog<ScheduledReturnDraft>(
      context: context,
      builder: (_) => ScheduleReturnDialog(
        day: day,
        loans: availableLoans,
        initialLoan: loan,
      ),
    );
    if (result == null) return;
    await onScheduleReturn(
      result.loan,
      result.dueAt,
      result.amount,
      result.note,
    );
    if (context.mounted) Navigator.pop(context);
  }
}

class TariffsView extends StatelessWidget {
  const TariffsView({
    required this.tariffs,
    required this.showDebtorTotals,
    required this.onShowDebtorTotalsChanged,
    required this.onEditTariff,
    super.key,
  });

  final List<DebtTariff> tariffs;
  final bool showDebtorTotals;
  final ValueChanged<bool> onShowDebtorTotalsChanged;
  final ValueChanged<DebtTariff> onEditTariff;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'НАСТРОЙКИ ПРИЛОЖЕНИЯ',
            title: 'Настройки',
            subtitle: 'Отображение списка должников и условия займов.',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 20),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                value: showDebtorTotals,
                onChanged: onShowDebtorTotalsChanged,
                title: const Text(
                  'Показывать общую сумму в списке должников',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Если выключить, в списке останутся имена и ближайший возврат.',
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionLabel(text: 'ТАРИФЫ', count: tariffs.length),
        ),
        if (tariffs.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: EmptyCard(text: 'Тарифы пока не загружены'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: 20),
            sliver: SliverList.separated(
              itemCount: tariffs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final tariff = tariffs[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFDCEAE3),
                      child: Icon(
                        tariff.isDefault ? Icons.star : Icons.percent,
                        color: const Color(0xFF123D34),
                      ),
                    ),
                    title: Text(
                      tariff.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${percent(tariff.monthlyPercent)} в месяц • ${percent(tariff.dailyPercent)} в день',
                    ),
                    trailing: IconButton(
                      tooltip: 'Изменить тариф',
                      onPressed: () => onEditTariff(tariff),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class LoanDetailsPage extends StatefulWidget {
  const LoanDetailsPage({
    required this.loan,
    required this.onEditLoan,
    required this.onAddPayment,
    required this.onAddLoanForDebtor,
    required this.onArchiveLoan,
    required this.onDeleteLoan,
    required this.onCloseEarly,
    super.key,
  });

  final Loan loan;
  final Future<Loan?> Function(Loan) onEditLoan;
  final Future<Loan?> Function(Loan) onAddPayment;
  final Future<void> Function(Loan) onAddLoanForDebtor;
  final Future<Loan?> Function(Loan) onArchiveLoan;
  final Future<bool> Function(Loan) onDeleteLoan;
  final Future<Loan?> Function(Loan) onCloseEarly;

  @override
  State<LoanDetailsPage> createState() => _LoanDetailsPageState();
}

class _LoanDetailsPageState extends State<LoanDetailsPage> {
  late DateTime _shownMonth;
  late Loan _loan;

  @override
  void initState() {
    super.initState();
    _loan = widget.loan;
    final now = DateTime.now();
    _shownMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final loan = _loan;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final calendar = LoanCalendar(
      loan: loan,
      month: _shownMonth,
      onPrevious: () => setState(() {
        _shownMonth = DateTime(_shownMonth.year, _shownMonth.month - 1);
      }),
      onNext: () => setState(() {
        _shownMonth = DateTime(_shownMonth.year, _shownMonth.month + 1);
      }),
    );
    final summary = LoanSummaryPanel(loan: loan);

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.debtorName),
        backgroundColor: const Color(0xFFF7F4ED),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            PageHeader(
              eyebrow: loan.isActive ? 'АКТИВНЫЙ ДОЛГ' : 'ДОЛГ ЗАКРЫТ',
              title: loan.debtorName,
              subtitle: loan.note.isEmpty ? loan.conditionLabel : loan.note,
              action: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final updated = await widget.onEditLoan(_loan);
                      if (updated != null && mounted) {
                        setState(() => _loan = updated);
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Редактировать'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => widget.onAddLoanForDebtor(_loan),
                    icon: const Icon(Icons.add),
                    label: const Text('Еще займ'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            LoanActionsPanel(
              loan: loan,
              onAddPayment: () async {
                final updated = await widget.onAddPayment(_loan);
                if (updated != null && mounted) {
                  setState(() => _loan = updated);
                }
              },
              onClose: loan.isActive
                  ? () async {
                      final updated = await widget.onCloseEarly(_loan);
                      if (updated != null && mounted) {
                        setState(() => _loan = updated);
                      }
                    }
                  : null,
              onArchive: !loan.isActive && loan.archivedAt == null
                  ? () async {
                      final navigator = Navigator.of(context);
                      final updated = await widget.onArchiveLoan(_loan);
                      if (updated != null && mounted) {
                        setState(() => _loan = updated);
                        navigator.pop();
                      }
                    }
                  : null,
              onDelete: () async {
                final navigator = Navigator.of(context);
                final deleted = await widget.onDeleteLoan(_loan);
                if (deleted && mounted) navigator.pop();
              },
            ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: calendar),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: summary),
                ],
              )
            else ...[
              summary,
              const SizedBox(height: 16),
              calendar,
            ],
            const SizedBox(height: 18),
            DailyAccrualList(loan: loan),
          ],
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 18,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: Color(0xFF9A5B2C),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
        if (action != null) action!,
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: tone),
              Text(
                value,
                style: TextStyle(
                  color: tone,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoanActionsPanel extends StatelessWidget {
  const LoanActionsPanel({
    required this.loan,
    required this.onAddPayment,
    required this.onDelete,
    this.onClose,
    this.onArchive,
    super.key,
  });

  final Loan loan;
  final VoidCallback onAddPayment;
  final VoidCallback? onClose;
  final VoidCallback? onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: loan.isActive ? onAddPayment : null,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Частичная оплата'),
            ),
            OutlinedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Закрыть'),
            ),
            OutlinedButton.icon(
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('В архив'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoanTile extends StatelessWidget {
  const LoanTile({required this.loan, required this.onTap, super.key});

  final Loan loan;
  final ValueChanged<Loan> onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Card(
      child: InkWell(
        onTap: () => onTap(loan),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: compact ? 22 : 24,
                backgroundColor: loan.isActive
                    ? const Color(0xFFDCEAE3)
                    : const Color(0xFFE7E3DA),
                child: Text(
                  initials(loan.debtorName),
                  style: const TextStyle(
                    color: Color(0xFF123D34),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            loan.debtorName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        SizedBox(
                          width: compact ? 86 : 98,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  money(loan.remainingDue),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loan.isActive
                                    ? dueCountdownLabel(loan.dueAt)
                                    : 'закрыт',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: loan.isActive
                                      ? const Color(0xFF9A5B2C)
                                      : Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 1),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.black38,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loanDateRangeLabel(loan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loan.conditionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RequestTile extends StatelessWidget {
  const RequestTile({
    required this.request,
    this.onApprove,
    this.onReject,
    this.onDelete,
    super.key,
  });

  final LoanRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final pending = request.status == 'pending';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.clientName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${request.days} дней  •  ${percent(request.dailyPercent)} в день',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  request.purpose,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(request.amount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (pending)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Удалить заявку',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      TextButton(
                        onPressed: onReject,
                        child: const Text('Отказать'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: onApprove,
                        child: const Text('Одобрить'),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusChip(status: request.status),
                      IconButton(
                        tooltip: 'Удалить заявку',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LoanSummaryPanel extends StatelessWidget {
  const LoanSummaryPanel({required this.loan, super.key});

  final Loan loan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Условия займа',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _SummaryRow(label: 'Выдано', value: money(loan.principal)),
            if (loan.isFixedRepayment)
              _SummaryRow(label: 'Формат', value: 'фиксированный возврат')
            else ...[
              _SummaryRow(
                label: 'Ставка',
                value: '${percent(loan.dailyPercent)} / день',
              ),
              _SummaryRow(
                label: 'Начислено дней',
                value: '${loan.accruedDays}',
              ),
            ],
            _SummaryRow(label: 'Доход', value: money(loan.interest)),
            const Divider(height: 24),
            _SummaryRow(
              label: 'К возврату всего',
              value: money(loan.expectedDue),
            ),
            if (loan.paidAmount > 0)
              _SummaryRow(label: 'Уже внесено', value: money(loan.paidAmount)),
            _SummaryRow(
              label: 'Осталось',
              value: money(loan.remainingDue),
              strong: true,
            ),
            const SizedBox(height: 14),
            Text(
              loan.isActive
                  ? duePlanLabel(loan.dueAt)
                  : 'Закрыт: ${shortDate(loan.closedAt!)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 20 : 15,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class LoanCalendar extends StatelessWidget {
  const LoanCalendar({
    required this.loan,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final Loan loan;
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthLabel(month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                _WeekDay('ПН'),
                _WeekDay('ВТ'),
                _WeekDay('СР'),
                _WeekDay('ЧТ'),
                _WeekDay('ПТ'),
                _WeekDay('СБ'),
                _WeekDay('ВС'),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leading + count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.15,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemBuilder: (_, index) {
                if (index < leading) return const SizedBox.shrink();
                final day = DateTime(
                  month.year,
                  month.month,
                  index - leading + 1,
                );
                final active = loan.isAccruedOn(day);
                final due = loan.isDueOn(day);
                final issued = sameDay(day, loan.issuedAt);
                final closed =
                    loan.closedAt != null && sameDay(day, loan.closedAt!);
                final tone = debtorColor(loan.debtorName);
                return Container(
                  decoration: BoxDecoration(
                    color: due
                        ? tone.withValues(alpha: 0.22)
                        : active
                        ? const Color(0xFFDCEAE3)
                        : const Color(0xFFF3F1EB),
                    borderRadius: BorderRadius.circular(9),
                    border: due || issued || closed
                        ? Border.all(
                            color: due ? tone : const Color(0xFF9A5B2C),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (due)
                        Text(
                          money(loan.remainingDue, decimals: 0),
                          style: const TextStyle(
                            color: Color(0xFF123D34),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else if (active && !loan.isFixedRepayment)
                        Text(
                          '+${money(loan.dailyInterest, decimals: 0)}',
                          style: const TextStyle(
                            color: Color(0xFF123D34),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black45,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class DailyAccrualList extends StatelessWidget {
  const DailyAccrualList({required this.loan, super.key});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    if (loan.isFixedRepayment) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.event_available_outlined),
          title: Text(
            loan.dueAt == null
                ? 'Дата возврата не назначена'
                : 'Ожидается ${longDate(loan.dueAt!)}',
          ),
          subtitle: Text('Доход: ${money(loan.interest)}'),
          trailing: Text(
            money(loan.remainingDue),
            style: const TextStyle(
              color: Color(0xFF123D34),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final days = loan.accrualDates.reversed.take(10).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Последние начисления',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (days.isEmpty)
              const Text(
                'Начислений пока нет',
                style: TextStyle(color: Colors.black54),
              )
            else
              ...days.map(
                (day) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, size: 18),
                  title: Text(longDate(day)),
                  trailing: Text(
                    '+${money(loan.dailyInterest)}',
                    style: const TextStyle(
                      color: Color(0xFF123D34),
                      fontWeight: FontWeight.w800,
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

class CreateLoanDialog extends StatefulWidget {
  const CreateLoanDialog({
    required this.tariffs,
    required this.debtors,
    required this.recentDebtors,
    this.initialDebtorName,
    super.key,
  });

  final List<DebtTariff> tariffs;
  final List<String> debtors;
  final List<String> recentDebtors;
  final String? initialDebtorName;

  @override
  State<CreateLoanDialog> createState() => _CreateLoanDialogState();
}

class EditTariffDialog extends StatefulWidget {
  const EditTariffDialog({required this.tariff, super.key});

  final DebtTariff tariff;

  @override
  State<EditTariffDialog> createState() => _EditTariffDialogState();
}

class _EditTariffDialogState extends State<EditTariffDialog> {
  late final TextEditingController _name;
  late final TextEditingController _monthlyPercent;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.tariff.name);
    _monthlyPercent = TextEditingController(
      text: widget.tariff.monthlyPercent.toString(),
    );
    _description = TextEditingController(text: widget.tariff.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _monthlyPercent.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 48;

    return AlertDialog(
      title: const Text('Управление тарифом'),
      content: SizedBox(
        width: width.clamp(280, 500).toDouble(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _monthlyPercent,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Процент в месяц'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
          ],
        ),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final monthly = double.tryParse(
                  _monthlyPercent.text.replaceAll(',', '.'),
                );
                if (_name.text.trim().isEmpty || monthly == null) return;

                Navigator.pop(
                  context,
                  DebtTariff(
                    id: widget.tariff.id,
                    name: _name.text.trim(),
                    monthlyPercent: monthly,
                    dailyPercent: monthly / 30,
                    isDefault: widget.tariff.isDefault,
                    description: _description.text.trim(),
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CreateLoanDialogState extends State<CreateLoanDialog> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _amount = TextEditingController();
  final _repaymentAmount = TextEditingController();
  late final TextEditingController _percent;
  final _note = TextEditingController();
  bool _fixedRepayment = false;
  late DateTime _issuedAt;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _issuedAt = dateOnly(DateTime.now());
    _dueAt = addMonths(_issuedAt, 1);
    if (widget.initialDebtorName != null) {
      _name.text = widget.initialDebtorName!;
    }
    DebtTariff? defaultTariff;
    for (final tariff in widget.tariffs) {
      if (tariff.isDefault) {
        defaultTariff = tariff;
        break;
      }
    }
    _percent = TextEditingController(
      text: clearNumber(defaultTariff?.dailyPercent ?? 0.5),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _amount.dispose();
    _repaymentAmount.dispose();
    _percent.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickIssuedAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issuedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() {
      _issuedAt = dateOnly(picked);
      if (_dueAt != null && _dueAt!.isBefore(_issuedAt)) {
        _dueAt = addMonths(_issuedAt, 1);
      }
    });
  }

  Future<void> _pickDueAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? addMonths(_issuedAt, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked == null) return;
    setState(() => _dueAt = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogWidth = media.size.width - 48;
    final contentHeight = (media.size.height - media.viewInsets.bottom - 220)
        .clamp(260, 520)
        .toDouble();
    final frequent = widget.recentDebtors.take(6).toList();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      title: const Text('Новый займ'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: contentHeight,
          maxWidth: dialogWidth.clamp(280, 500).toDouble(),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                focusNode: _nameFocus,
                decoration: dialogInputDecoration('Имя должника'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.debtors.isEmpty
                        ? null
                        : () async {
                            final debtor = await showModalBottomSheet<String>(
                              useSafeArea: true,
                              context: context,
                              isScrollControlled: true,
                              builder: (_) =>
                                  DebtorPickerSheet(debtors: widget.debtors),
                            );
                            if (debtor != null) {
                              _name.text = debtor;
                            }
                          },
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Выбрать из списка'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _name.clear();
                      _nameFocus.requestFocus();
                    },
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Новый должник'),
                  ),
                ],
              ),
              if (frequent.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Частые / последние',
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: frequent
                            .map(
                              (debtor) => ActionChip(
                                label: Text(debtor),
                                onPressed: () => _name.text = debtor,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: dialogInputDecoration('Дали сумму'),
              ),
              const SizedBox(height: 10),
              DialogDateField(
                label: 'Дата выдачи',
                value: shortDate(_issuedAt),
                icon: Icons.calendar_month_outlined,
                onTap: _pickIssuedAt,
              ),
              const SizedBox(height: 10),
              FixedRepaymentToggle(
                value: _fixedRepayment,
                subtitle: 'Например: дали 1000, вернуть 1200',
                onChanged: (value) => setState(() {
                  _fixedRepayment = value;
                  if (value && _repaymentAmount.text.trim().isEmpty) {
                    _repaymentAmount.text = _amount.text.trim();
                  }
                }),
              ),
              const SizedBox(height: 10),
              if (_fixedRepayment)
                TextField(
                  controller: _repaymentAmount,
                  keyboardType: TextInputType.number,
                  decoration: dialogInputDecoration('Сколько вернуть'),
                )
              else
                TextField(
                  controller: _percent,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: dialogInputDecoration(
                    'Процент в день',
                    suffixText: '% в день',
                  ),
                ),
              const SizedBox(height: 10),
              OptionalDateField(
                label: 'Дата возврата',
                value: _dueAt,
                icon: Icons.event_available_outlined,
                onTap: _pickDueAt,
                onClear: () => setState(() => _dueAt = null),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: dialogInputDecoration('Комментарий'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final amount = parseMoneyInput(_amount.text);
                final repaymentAmount = parseMoneyInput(_repaymentAmount.text);
                final rate = parseMoneyInput(_percent.text);
                if (_name.text.trim().isEmpty ||
                    amount == null ||
                    (!_fixedRepayment && rate == null) ||
                    (_fixedRepayment && repaymentAmount == null)) {
                  return;
                }
                final issued = _issuedAt;
                Navigator.pop(
                  context,
                  Loan(
                    id: 'loan-${DateTime.now().microsecondsSinceEpoch}',
                    debtorName: _name.text.trim(),
                    phone: '',
                    principal: amount,
                    repaymentAmount: _fixedRepayment ? repaymentAmount : null,
                    issuedAt: issued,
                    dueAt: _dueAt,
                    dailyPercent: _fixedRepayment ? 0 : rate!,
                    note: _note.text.trim(),
                  ),
                );
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ],
    );
  }
}

class EditLoanDialog extends StatefulWidget {
  const EditLoanDialog({required this.loan, super.key});

  final Loan loan;

  @override
  State<EditLoanDialog> createState() => _EditLoanDialogState();
}

class _EditLoanDialogState extends State<EditLoanDialog> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _repaymentAmount;
  late final TextEditingController _percent;
  late final TextEditingController _note;
  late DateTime _issuedAt;
  DateTime? _dueAt;
  late bool _fixedRepayment;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    _name = TextEditingController(text: loan.debtorName);
    _amount = TextEditingController(text: clearNumber(loan.principal));
    _repaymentAmount = TextEditingController(
      text: clearNumber(loan.expectedDue),
    );
    _percent = TextEditingController(text: clearNumber(loan.dailyPercent));
    _note = TextEditingController(text: loan.note);
    _issuedAt = loan.issuedAt;
    _dueAt = loan.dueAt;
    _fixedRepayment =
        loan.isFixedRepayment || loan.expectedReturnAmount != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _repaymentAmount.dispose();
    _percent.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickIssuedAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issuedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _issuedAt = dateOnly(picked));
  }

  Future<void> _pickDueAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? addMonths(_issuedAt, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _dueAt = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogWidth = media.size.width - 48;
    final contentHeight = (media.size.height - media.viewInsets.bottom - 220)
        .clamp(260, 520)
        .toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      title: const Text('Редактировать займ'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: contentHeight,
          maxWidth: dialogWidth.clamp(280, 500).toDouble(),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: dialogInputDecoration('Имя должника'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: dialogInputDecoration('Дали сумму'),
              ),
              const SizedBox(height: 10),
              DialogDateField(
                label: 'Дата выдачи',
                value: shortDate(_issuedAt),
                icon: Icons.calendar_month_outlined,
                onTap: _pickIssuedAt,
              ),
              const SizedBox(height: 10),
              OptionalDateField(
                label: 'Дата возврата',
                value: _dueAt,
                icon: Icons.event_available_outlined,
                onTap: _pickDueAt,
                onClear: () => setState(() => _dueAt = null),
              ),
              const SizedBox(height: 10),
              FixedRepaymentToggle(
                value: _fixedRepayment,
                onChanged: (value) => setState(() => _fixedRepayment = value),
              ),
              const SizedBox(height: 10),
              if (_fixedRepayment)
                TextField(
                  controller: _repaymentAmount,
                  keyboardType: TextInputType.number,
                  decoration: dialogInputDecoration('Сколько вернуть всего'),
                )
              else
                TextField(
                  controller: _percent,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: dialogInputDecoration(
                    'Процент в день',
                    suffixText: '% в день',
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 3,
                decoration: dialogInputDecoration('Комментарий'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final amount = parseMoneyInput(_amount.text);
                final repaymentAmount = parseMoneyInput(_repaymentAmount.text);
                final rate = parseMoneyInput(_percent.text);
                if (_name.text.trim().isEmpty ||
                    amount == null ||
                    (_fixedRepayment && repaymentAmount == null) ||
                    (!_fixedRepayment && rate == null)) {
                  return;
                }
                Navigator.pop(
                  context,
                  Loan(
                    id: widget.loan.id,
                    debtorName: _name.text.trim(),
                    phone: widget.loan.phone,
                    principal: amount,
                    repaymentAmount: _fixedRepayment ? repaymentAmount : null,
                    issuedAt: _issuedAt,
                    dueAt: _dueAt,
                    dailyPercent: _fixedRepayment ? 0 : rate!,
                    note: _note.text.trim(),
                    paidAmount: widget.loan.paidAmount,
                    archivedAt: widget.loan.archivedAt,
                    closedAt: widget.loan.closedAt,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }
}

class LoanPaymentDraft {
  const LoanPaymentDraft({required this.amount, required this.note});

  final double amount;
  final String note;
}

class AddPaymentDialog extends StatefulWidget {
  const AddPaymentDialog({required this.loan, super.key});

  final Loan loan;

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _amount = TextEditingController();
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.loan.note);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.sizeOf(context).width - 48;
    return AlertDialog(
      title: const Text('Частичная оплата'),
      content: SizedBox(
        width: dialogWidth.clamp(280, 500).toDouble(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Сейчас осталось: ${money(widget.loan.remainingDue)}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Сколько внес'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
          ],
        ),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final amount = parseMoneyInput(_amount.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(
                  context,
                  LoanPaymentDraft(amount: amount, note: _note.text.trim()),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }
}

class CreateRequestDialog extends StatefulWidget {
  const CreateRequestDialog({required this.tariffs, super.key});

  final List<DebtTariff> tariffs;

  @override
  State<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<CreateRequestDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  late final TextEditingController _percent;
  final _days = TextEditingController(text: '7');
  final _purpose = TextEditingController();

  @override
  void initState() {
    super.initState();
    DebtTariff? defaultTariff;
    for (final tariff in widget.tariffs) {
      if (tariff.isDefault) {
        defaultTariff = tariff;
        break;
      }
    }
    _percent = TextEditingController(
      text: clearNumber(defaultTariff?.dailyPercent ?? 0.5),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _amount.dispose();
    _percent.dispose();
    _days.dispose();
    _purpose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogWidth = media.size.width - 48;
    final contentHeight = (media.size.height - media.viewInsets.bottom - 220)
        .clamp(260, 520)
        .toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      title: const Text('Новая заявка'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: contentHeight,
          maxWidth: dialogWidth.clamp(280, 500).toDouble(),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: dialogInputDecoration('Кто просит'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: dialogInputDecoration('Телефон'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: dialogInputDecoration('Сумма заявки'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: dialogInputDecoration('На сколько дней'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _percent,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: dialogInputDecoration(
                  'Процент в день',
                  suffixText: '% в день',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _purpose,
                minLines: 2,
                maxLines: 3,
                decoration: dialogInputDecoration('Комментарий'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final amount = parseMoneyInput(_amount.text);
                final rate = parseMoneyInput(_percent.text);
                final days = int.tryParse(_days.text);
                if (_name.text.trim().isEmpty ||
                    amount == null ||
                    rate == null ||
                    days == null) {
                  return;
                }
                Navigator.pop(
                  context,
                  LoanRequest(
                    id: 'request-${DateTime.now().microsecondsSinceEpoch}',
                    clientName: _name.text.trim(),
                    phone: _phone.text.trim(),
                    amount: amount,
                    days: days,
                    dailyPercent: rate,
                    purpose: _purpose.text.trim().isEmpty
                        ? 'Без комментария'
                        : _purpose.text.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ],
    );
  }
}

class ScheduledReturnDraft {
  const ScheduledReturnDraft({
    required this.loan,
    required this.dueAt,
    required this.amount,
    required this.note,
  });

  final Loan loan;
  final DateTime dueAt;
  final double amount;
  final String note;
}

class ScheduleReturnDialog extends StatefulWidget {
  const ScheduleReturnDialog({
    required this.day,
    required this.loans,
    this.initialLoan,
    super.key,
  });

  final DateTime day;
  final List<Loan> loans;
  final Loan? initialLoan;

  @override
  State<ScheduleReturnDialog> createState() => _ScheduleReturnDialogState();
}

class _ScheduleReturnDialogState extends State<ScheduleReturnDialog> {
  late Loan _loan;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _loan = widget.initialLoan ?? widget.loans.first;
    _amount = TextEditingController(text: clearNumber(_loan.remainingDue));
    _note = TextEditingController(text: _loan.note);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.sizeOf(context).width - 48;
    return AlertDialog(
      title: Text('Выплата на ${shortDate(widget.day)}'),
      content: SizedBox(
        width: dialogWidth.clamp(280, 500).toDouble(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Loan>(
              initialValue: _loan,
              decoration: const InputDecoration(labelText: 'Должник'),
              items: widget.loans
                  .map(
                    (loan) => DropdownMenuItem(
                      value: loan,
                      child: Text(
                        loan.debtorName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.initialLoan == null
                  ? (loan) {
                      if (loan == null) return;
                      setState(() {
                        _loan = loan;
                        _amount.text = clearNumber(loan.remainingDue);
                        _note.text = loan.note;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Сколько жду'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
          ],
        ),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final amount = parseMoneyInput(_amount.text);
                if (amount == null) return;
                Navigator.pop(
                  context,
                  ScheduledReturnDraft(
                    loan: _loan,
                    dueAt: widget.day,
                    amount: amount,
                    note: _note.text.trim(),
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }
}

class DebtorPickerSheet extends StatefulWidget {
  const DebtorPickerSheet({required this.debtors, super.key});

  final List<String> debtors;

  @override
  State<DebtorPickerSheet> createState() => _DebtorPickerSheetState();
}

class _DebtorPickerSheetState extends State<DebtorPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = widget.debtors
        .where((name) => query.isEmpty || name.toLowerCase().contains(query))
        .toList();

    return SafeArea(
      child: Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выбрать должника',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Поиск по имени',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Ничего не найдено'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final name = items[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: debtorColor(
                            name,
                          ).withValues(alpha: 0.18),
                          child: Text(
                            initials(name),
                            style: const TextStyle(
                              color: Color(0xFF123D34),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(name),
                        onTap: () => Navigator.pop(context, name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.text, required this.count, super.key});
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Text(
        '$text  $count',
        style: const TextStyle(
          color: Colors.black45,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, style: const TextStyle(color: Colors.black54)),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'approved';
    return Chip(
      label: Text(approved ? 'Одобрено' : 'Отказ'),
      backgroundColor: approved
          ? const Color(0xFFDCEAE3)
          : const Color(0xFFF4DEDE),
      side: BorderSide.none,
    );
  }
}

class FixedRepaymentToggle extends StatelessWidget {
  const FixedRepaymentToggle({
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Фиксированная сумма возврата',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.16,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class DialogDateField extends StatelessWidget {
  const DialogDateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF65746B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: Color(0xFF3A4641), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class OptionalDateField extends StatelessWidget {
  const OptionalDateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.onClear,
    super.key,
  });

  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasDate = value != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF65746B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasDate ? shortDate(value!) : 'Без даты возврата',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasDate ? Colors.black87 : Colors.black45,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasDate)
                IconButton(
                  tooltip: 'Убрать дату',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
              Icon(icon, color: const Color(0xFF3A4641), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

const _unset = Object();

class Loan {
  Loan({
    required this.id,
    required this.debtorName,
    required this.phone,
    required this.principal,
    this.repaymentAmount,
    required this.issuedAt,
    this.dueAt,
    required this.dailyPercent,
    required this.note,
    this.expectedReturnAmount,
    this.paidAmount = 0,
    this.archivedAt,
    this.closedAt,
  });

  final String id;
  final String debtorName;
  final String phone;
  final double principal;
  final double? repaymentAmount;
  final DateTime issuedAt;
  final DateTime? dueAt;
  final double dailyPercent;
  final String note;
  final double? expectedReturnAmount;
  final double paidAmount;
  final DateTime? archivedAt;
  DateTime? closedAt;

  bool get isActive => closedAt == null;
  DateTime get calculationEnd => closedAt ?? dateOnly(DateTime.now());
  bool get isFixedRepayment => repaymentAmount != null;
  double get dailyInterest =>
      isFixedRepayment ? 0 : principal * dailyPercent / 100;
  String get conditionLabel => isFixedRepayment
      ? 'вернуть ${money(remainingDue)}'
      : '${percent(dailyPercent)} в день';
  int get accruedDays => accrualDates.length;
  double get interest {
    if (repaymentAmount != null) {
      final value = repaymentAmount! - principal;
      return value > 0 ? value : 0;
    }
    return dailyInterest * accruedDays;
  }

  double get totalDue => repaymentAmount ?? principal + interest;
  double get expectedDue => expectedReturnAmount ?? totalDue;
  double get remainingDue {
    final value = expectedDue - paidAmount;
    return value > 0 ? value : 0;
  }

  List<DateTime> get accrualDates {
    if (calculationEnd.isBefore(issuedAt)) return [];
    final count = calculationEnd.difference(issuedAt).inDays + 1;
    return List.generate(count, (index) => issuedAt.add(Duration(days: index)));
  }

  bool isAccruedOn(DateTime date) {
    final value = dateOnly(date);
    return !value.isBefore(issuedAt) && !value.isAfter(calculationEnd);
  }

  bool isDueOn(DateTime date) => dueAt != null && sameDay(date, dueAt!);

  Loan copyWith({
    Object? dueAt = _unset,
    double? expectedReturnAmount,
    double? paidAmount,
    DateTime? archivedAt,
    String? note,
    DateTime? closedAt,
  }) {
    return Loan(
      id: id,
      debtorName: debtorName,
      phone: phone,
      principal: principal,
      repaymentAmount: repaymentAmount,
      issuedAt: issuedAt,
      dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as DateTime?,
      dailyPercent: dailyPercent,
      note: note ?? this.note,
      expectedReturnAmount: expectedReturnAmount ?? this.expectedReturnAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      archivedAt: archivedAt ?? this.archivedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'debtorName': debtorName,
    'phone': phone,
    'principal': principal,
    'repaymentAmount': repaymentAmount,
    'issuedAt': issuedAt.toIso8601String(),
    'dueAt': dueAt?.toIso8601String(),
    'dailyPercent': dailyPercent,
    'note': note,
    'expectedReturnAmount': expectedReturnAmount,
    'paidAmount': paidAmount,
    'archivedAt': archivedAt?.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
  };

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
    id: json['id'].toString(),
    debtorName: json['debtorName'] as String,
    phone: (json['phone'] ?? '') as String,
    principal: (json['principal'] as num).toDouble(),
    repaymentAmount: (json['repaymentAmount'] as num?)?.toDouble(),
    issuedAt: DateTime.parse(json['issuedAt'] as String),
    dueAt: json['dueAt'] == null
        ? null
        : DateTime.parse(json['dueAt'] as String),
    dailyPercent: (json['dailyPercent'] as num).toDouble(),
    note: (json['note'] ?? '') as String,
    expectedReturnAmount: (json['expectedReturnAmount'] as num?)?.toDouble(),
    paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
    archivedAt: json['archivedAt'] == null
        ? null
        : DateTime.parse(json['archivedAt'] as String),
    closedAt: json['closedAt'] == null
        ? null
        : DateTime.parse(json['closedAt'] as String),
  );
}

class LoanRequest {
  LoanRequest({
    required this.id,
    required this.clientName,
    required this.phone,
    required this.amount,
    required this.days,
    required this.dailyPercent,
    required this.purpose,
    required this.createdAt,
    this.status = 'pending',
  });

  final String id;
  final String clientName;
  final String phone;
  final double amount;
  final int days;
  final double dailyPercent;
  final String purpose;
  final DateTime createdAt;
  String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientName': clientName,
    'phone': phone,
    'amount': amount,
    'days': days,
    'dailyPercent': dailyPercent,
    'purpose': purpose,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };

  factory LoanRequest.fromJson(Map<String, dynamic> json) => LoanRequest(
    id: json['id'].toString(),
    clientName: json['clientName'] as String,
    phone: (json['phone'] ?? '') as String,
    amount: (json['amount'] as num).toDouble(),
    days: json['days'] as int,
    dailyPercent: (json['dailyPercent'] as num).toDouble(),
    purpose: (json['purpose'] ?? '') as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: (json['status'] ?? 'pending') as String,
  );
}

class DebtTariff {
  const DebtTariff({
    required this.id,
    required this.name,
    required this.monthlyPercent,
    required this.dailyPercent,
    required this.isDefault,
    this.description = '',
  });

  final int id;
  final String name;
  final double monthlyPercent;
  final double dailyPercent;
  final bool isDefault;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'monthlyPercent': monthlyPercent,
    'dailyPercent': dailyPercent,
    'isDefault': isDefault,
    'description': description,
  };

  factory DebtTariff.fromJson(Map<String, dynamic> json) => DebtTariff(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    monthlyPercent: (json['monthlyPercent'] as num).toDouble(),
    dailyPercent: (json['dailyPercent'] as num).toDouble(),
    isDefault: json['isDefault'] == true,
    description: (json['description'] ?? '') as String,
  );
}

class DebtData {
  const DebtData({
    required this.loans,
    required this.requests,
    required this.tariffs,
    this.debtorPhotos = const {},
    this.debtorSortMode = DebtorSortMode.dueDate,
    this.showDebtorTotals = true,
  });
  final List<Loan> loans;
  final List<LoanRequest> requests;
  final List<DebtTariff> tariffs;
  final Map<String, String> debtorPhotos;
  final DebtorSortMode debtorSortMode;
  final bool showDebtorTotals;
}

class DebtRepository {
  static const _key = 'debt_manager_local_data_v1';
  static const _apiBase = 'https://college.panfilius.ru/api/debts';

  bool _remoteAvailable = false;

  Future<DebtData> load() async {
    _remoteAvailable = false;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return seedData();
    final json = jsonDecode(stored) as Map<String, dynamic>;
    final fallbackTariffs = seedData().tariffs;
    return DebtData(
      loans: (json['loans'] as List)
          .map((item) => Loan.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      requests: (json['requests'] as List)
          .map(
            (item) =>
                LoanRequest.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      tariffs:
          (json['tariffs'] as List?)
              ?.map(
                (item) =>
                    DebtTariff.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList() ??
          fallbackTariffs,
      debtorPhotos: Map<String, String>.from(
        (json['debtorPhotos'] as Map?) ?? const {},
      ),
      debtorSortMode: debtorSortModeFromJson(json['debtorSortMode']),
      showDebtorTotals: json['showDebtorTotals'] != false,
    );
  }

  Future<void> save(
    List<Loan> loans,
    List<LoanRequest> requests,
    List<DebtTariff> tariffs,
    bool showDebtorTotals,
    Map<String, String> debtorPhotos,
    DebtorSortMode debtorSortMode,
  ) async {
    if (_remoteAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'loans': loans.map((item) => item.toJson()).toList(),
        'requests': requests.map((item) => item.toJson()).toList(),
        'tariffs': tariffs.map((item) => item.toJson()).toList(),
        'showDebtorTotals': showDebtorTotals,
        'debtorPhotos': debtorPhotos,
        'debtorSortMode': debtorSortMode.name,
      }),
    );
  }

  Future<Loan> createLoan(Loan loan) async {
    if (!_remoteAvailable) return loan;

    final response = await _post('/loans', {
      'debtor_name': loan.debtorName,
      'phone': loan.phone,
      'principal': loan.principal,
      'repayment_amount': loan.repaymentAmount,
      'issued_at': apiDate(loan.issuedAt),
      'due_at': loan.dueAt == null ? null : apiDate(loan.dueAt!),
      'daily_percent': loan.dailyPercent,
      'monthly_percent': loan.dailyPercent * 30,
      'note': loan.note,
    });

    return Loan.fromJson(Map<String, dynamic>.from(response['loan'] as Map));
  }

  Future<Loan> closeLoan(Loan loan) async {
    if (!_remoteAvailable) {
      loan.closedAt = dateOnly(DateTime.now());
      return loan;
    }

    final response = await _post('/loans/${loan.id}/close', {
      'closed_at': apiDate(DateTime.now()),
    });

    return Loan.fromJson(Map<String, dynamic>.from(response['loan'] as Map));
  }

  Future<DebtData> approveRequest(LoanRequest request) async {
    if (!_remoteAvailable) {
      final data = await load();
      final target = data.requests.firstWhere(
        (item) => item.id == request.id,
        orElse: () => request,
      );
      target.status = 'approved';
      data.loans.insert(
        0,
        Loan(
          id: 'loan-${DateTime.now().microsecondsSinceEpoch}',
          debtorName: request.clientName,
          phone: request.phone,
          principal: request.amount,
          issuedAt: dateOnly(DateTime.now()),
          dueAt: dateOnly(DateTime.now().add(Duration(days: request.days))),
          dailyPercent: request.dailyPercent,
          note: 'Создано из заявки ${request.id}',
        ),
      );
      return data;
    }

    await _post('/requests/${request.id}/approve', {});
    return _fetchOverview();
  }

  Future<DebtTariff> updateTariff(DebtTariff tariff) async {
    if (!_remoteAvailable) return tariff;

    final response = await _put('/tariffs/${tariff.id}', {
      'name': tariff.name,
      'monthly_percent': tariff.monthlyPercent,
      'description': tariff.description,
      'is_default': tariff.isDefault,
    });

    return DebtTariff.fromJson(
      Map<String, dynamic>.from(response['tariff'] as Map),
    );
  }

  Future<DebtData> rejectRequest(LoanRequest request) async {
    if (!_remoteAvailable) {
      final data = await load();
      final target = data.requests.firstWhere(
        (item) => item.id == request.id,
        orElse: () => request,
      );
      target.status = 'rejected';
      return data;
    }

    await _post('/requests/${request.id}/reject', {});
    return _fetchOverview();
  }

  Future<DebtData> _fetchOverview() async {
    final uri = Uri.parse('$_apiBase/overview');
    final response = await http.get(uri, headers: _headers);
    final json = _decodeResponse(response);

    return DebtData(
      loans: (json['loans'] as List)
          .map((item) => Loan.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      requests: (json['requests'] as List)
          .map(
            (item) =>
                LoanRequest.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      tariffs: (json['tariffs'] as List? ?? [])
          .map(
            (item) =>
                DebtTariff.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$_apiBase$path'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.put(
      Uri.parse('$_apiBase$path'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['message'] ?? 'API error ${response.statusCode}');
    }
    return decoded;
  }

  Map<String, String> get _headers => const {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  DebtData seedData() {
    final today = dateOnly(DateTime.now());
    return DebtData(
      loans: [
        Loan(
          id: 'loan-1',
          debtorName: 'Алексей Морозов',
          phone: '+7 921 555-18-24',
          principal: 180000,
          issuedAt: today.subtract(const Duration(days: 13)),
          dueAt: today.add(const Duration(days: 17)),
          dailyPercent: 0.45,
          note: 'До зарплаты, перевод на карту',
        ),
        Loan(
          id: 'loan-2',
          debtorName: 'Мария Павлова',
          phone: '+7 911 820-44-01',
          principal: 95000,
          issuedAt: today.subtract(const Duration(days: 6)),
          dueAt: today.add(const Duration(days: 24)),
          dailyPercent: 0.55,
          note: 'Расходы на ремонт',
        ),
        Loan(
          id: 'loan-3',
          debtorName: 'Илья Фролов',
          phone: '+7 905 100-08-90',
          principal: 240000,
          issuedAt: today.subtract(const Duration(days: 22)),
          dueAt: today.add(const Duration(days: 8)),
          dailyPercent: 0.4,
          note: 'Рабочая закупка',
        ),
        Loan(
          id: 'loan-4',
          debtorName: 'Ольга Крылова',
          phone: '+7 921 004-17-43',
          principal: 70000,
          issuedAt: today.subtract(const Duration(days: 34)),
          dueAt: today.subtract(const Duration(days: 4)),
          dailyPercent: 0.5,
          note: 'Закрытый займ',
          closedAt: today.subtract(const Duration(days: 6)),
        ),
      ],
      requests: [
        LoanRequest(
          id: 'req-1',
          clientName: 'Антон Громов',
          phone: '+7 911 700-21-08',
          amount: 120000,
          days: 21,
          dailyPercent: 0.55,
          purpose: 'Закупка оборудования',
          createdAt: today,
        ),
        LoanRequest(
          id: 'req-2',
          clientName: 'Елена Соколова',
          phone: '+7 921 332-01-47',
          amount: 50000,
          days: 14,
          dailyPercent: 0.65,
          purpose: 'Личные расходы',
          createdAt: today.subtract(const Duration(days: 1)),
        ),
      ],
      tariffs: const [
        DebtTariff(
          id: 1,
          name: 'Основной тариф',
          monthlyPercent: 15,
          dailyPercent: 0.5,
          isDefault: true,
          description: 'Базовый тариф для новых займов',
        ),
      ],
    );
  }
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime addMonths(DateTime date, int months) {
  final targetMonth = date.month + months;
  final firstOfTarget = DateTime(date.year, targetMonth);
  final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(firstOfTarget.year, firstOfTarget.month, day);
}

int daysBetweenInclusive(DateTime start, DateTime end) {
  final value = dateOnly(end).difference(dateOnly(start)).inDays + 1;
  return value > 0 ? value : 0;
}

int compareNullableDates(DateTime? left, DateTime? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

String dueCountdownLabel(DateTime? dueAt) {
  if (dueAt == null) return 'без даты';
  final diff = dateOnly(dueAt).difference(dateOnly(DateTime.now())).inDays;
  if (diff < 0) return 'просрочено';
  if (diff == 0) return 'сегодня';
  if (diff == 1) return 'завтра';
  return 'через $diff ${dayWord(diff)}';
}

String duePlanLabel(DateTime? dueAt) => dueAt == null
    ? 'Дата возврата не назначена'
    : 'Плановый срок: ${shortDate(dueAt)}';

String loanDateRangeLabel(Loan loan) => loan.dueAt == null
    ? 'выдан ${compactDate(loan.issuedAt)} • без даты возврата'
    : '${compactDate(loan.issuedAt)} → ${compactDate(loan.dueAt!)}';

String dayWord(int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'дней';
  if (mod10 == 1) return 'день';
  if (mod10 >= 2 && mod10 <= 4) return 'дня';
  return 'дней';
}

String loanWord(int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'займов';
  if (mod10 == 1) return 'займ';
  if (mod10 >= 2 && mod10 <= 4) return 'займа';
  return 'займов';
}

String debtorKey(String name) => name.trim().toLowerCase();

String? debtorPhotoPath(Map<String, String> photos, String name) =>
    photos[debtorKey(name)];

bool sameDebtor(String left, String right) =>
    debtorKey(left) == debtorKey(right);

Future<String> saveDebtorPhoto(String debtorName, String sourcePath) async {
  final directory = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${directory.path}/debtor_photos');
  if (!photosDir.existsSync()) {
    photosDir.createSync(recursive: true);
  }
  final safeName = debtorKey(debtorName)
      .replaceAll(RegExp(r'[^a-zа-я0-9]+', caseSensitive: false), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final targetPath =
      '${photosDir.path}/${safeName}_${DateTime.now().microsecondsSinceEpoch}.jpg';
  final saved = await File(sourcePath).copy(targetPath);
  return saved.path;
}

List<DateTime> daysInMonth(DateTime month) {
  final count = DateTime(month.year, month.month + 1, 0).day;
  return List.generate(
    count,
    (index) => DateTime(month.year, month.month, index + 1),
  );
}

String apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
bool sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String money(double value, {int decimals = 0}) {
  final raw = value.toStringAsFixed(decimals);
  final parts = raw.split('.');
  final chars = parts.first.split('').reversed.toList();
  final groups = <String>[];
  for (var index = 0; index < chars.length; index += 3) {
    groups.add(chars.skip(index).take(3).toList().reversed.join());
  }
  final integer = groups.reversed.join(' ');
  return '${parts.length == 2 ? '$integer,${parts[1]}' : integer} ₽';
}

double? parseMoneyInput(String value) =>
    double.tryParse(value.replaceAll(',', '.').replaceAll(' ', ''));

InputDecoration dialogInputDecoration(
  String hint, {
  Widget? suffixIcon,
  String? suffixText,
}) => InputDecoration(
  hintText: hint,
  floatingLabelBehavior: FloatingLabelBehavior.never,
  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
  suffixIcon: suffixIcon,
  suffixText: suffixText,
  suffixStyle: const TextStyle(
    color: Color(0xFF65746B),
    fontWeight: FontWeight.w700,
  ),
);

String clearNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String percent(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')}%';
String compactDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${(value.year % 100).toString().padLeft(2, '0')}';
String shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
String longDate(DateTime value) {
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String monthLabel(DateTime value) {
  const months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String todayLabel() => 'СЕГОДНЯ, ${longDate(DateTime.now()).toUpperCase()}';
List<String> knownDebtors(List<Loan> loans) {
  final names = <String>{};
  for (final loan in loans) {
    final name = loan.debtorName.trim();
    if (name.isNotEmpty) names.add(name);
  }
  return names.toList()..sort();
}

List<String> recentDebtors(List<Loan> loans) {
  final sorted = [...loans]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  final names = <String>[];
  for (final loan in sorted) {
    final name = loan.debtorName.trim();
    if (name.isNotEmpty && !names.contains(name)) {
      names.add(name);
    }
  }
  return names;
}

Color debtorColor(String name) {
  const colors = [
    Color(0xFF13795B),
    Color(0xFFB35C2E),
    Color(0xFF38618C),
    Color(0xFF8E5572),
    Color(0xFF5D6B2F),
    Color(0xFF8A6D1D),
  ];
  final code = name.codeUnits.fold<int>(0, (sum, value) => sum + value);
  return colors[code % colors.length];
}

String initials(String name) => name
    .split(' ')
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0])
    .join();
