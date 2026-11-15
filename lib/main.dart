import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const UniNotasApp());

class UniNotasApp extends StatelessWidget {
  const UniNotasApp({super.key});
  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5B5BD6), brightness: b),
        );
    return MaterialApp(
      title: 'Uni Notas',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const Home(),
    );
  }
}

class Item {
  String id, title, subject, text;
  String kind; // examen | tarea | nota
  DateTime? date;
  bool done;
  Item(
      {required this.id,
      required this.title,
      this.subject = '',
      this.text = '',
      this.kind = 'nota',
      this.date,
      this.done = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'text': text,
        'kind': kind,
        'date': date?.toIso8601String(),
        'done': done,
      };
  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        title: j['title'],
        subject: j['subject'] ?? '',
        text: j['text'] ?? '',
        kind: j['kind'] ?? 'nota',
        date: j['date'] == null ? null : DateTime.parse(j['date']),
        done: j['done'] ?? false,
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Item> items = [];
  int tab = 0;
  final tabs = const ['examen', 'tarea', 'nota'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('items');
    if (raw != null) {
      items = (jsonDecode(raw) as List)
          .map((e) => Item.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    setState(() {});
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('items', jsonEncode(items.map((e) => e.toJson()).toList()));
    setState(() {});
  }

  String _when(DateTime d) {
    final days = DateTime(d.year, d.month, d.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day))
        .inDays;
    if (days < 0) return 'Pasó hace ${-days} d';
    if (days == 0) return 'Hoy';
    if (days == 1) return 'Mañana';
    return 'En $days días';
  }

  Future<void> _edit([Item? it]) async {
    final kind = tabs[tab];
    final title = TextEditingController(text: it?.title);
    final subject = TextEditingController(text: it?.subject);
    final text = TextEditingController(text: it?.text);
    DateTime? date = it?.date;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: title,
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: kind == 'examen'
                          ? 'Examen'
                          : kind == 'tarea'
                              ? 'Tarea'
                              : 'Título')),
              TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Materia')),
              TextField(
                  controller: text,
                  maxLines: 5,
                  minLines: 2,
                  decoration: const InputDecoration(labelText: 'Notas')),
              if (kind != 'nota')
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(date == null
                        ? 'Elegir fecha'
                        : '${date!.day}/${date!.month}/${date!.year}'),
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: ctx,
                          initialDate: date ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100));
                      if (d != null) set(() => date = d);
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Row(children: [
                if (it != null)
                  TextButton(
                      onPressed: () {
                        items.remove(it);
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Eliminar')),
                const Spacer(),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Guardar')),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (result == true && title.text.trim().isNotEmpty) {
      if (it == null) {
        items.add(Item(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title.text.trim(),
            subject: subject.text.trim(),
            text: text.text.trim(),
            kind: kind,
            date: date));
      } else if (items.contains(it)) {
        it
          ..title = title.text.trim()
          ..subject = subject.text.trim()
          ..text = text.text.trim()
          ..date = date;
      }
    }
    if (result == true) await _save();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = items.where((i) => i.kind == tabs[tab]).toList()
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return a.date!.compareTo(b.date!);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('Uni Notas'), centerTitle: false),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: list.isEmpty
              ? Center(
                  child: Text('Nada por aquí todavía',
                      style: TextStyle(color: cs.outline)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final it = list[i];
                    final soon = it.date != null &&
                        !it.done &&
                        it.date!.difference(DateTime.now()).inDays <= 3;
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      color: soon
                          ? cs.errorContainer
                          : cs.surfaceContainerHighest,
                      child: ListTile(
                        onTap: () => _edit(it),
                        leading: it.kind == 'nota'
                            ? const Icon(Icons.sticky_note_2_outlined)
                            : Checkbox(
                                value: it.done,
                                onChanged: (v) {
                                  it.done = v ?? false;
                                  _save();
                                }),
                        title: Text(it.title,
                            style: TextStyle(
                                decoration: it.done
                                    ? TextDecoration.lineThrough
                                    : null)),
                        subtitle: Text([
                          if (it.subject.isNotEmpty) it.subject,
                          if (it.text.isNotEmpty) it.text.split('\n').first,
                        ].join(' · ')),
                        trailing: it.date == null
                            ? null
                            : Text(_when(it.date!),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                      ),
                    );
                  }),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Añadir')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Exámenes'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Notas'),
        ],
      ),
    );
  }
}
