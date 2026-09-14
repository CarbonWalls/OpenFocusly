import 'package:flutter/foundation.dart';
import '../models/counter.dart';
import '../models/note.dart';

class Nav extends ChangeNotifier {
  int screen = 0, timeTab = 0;
  bool ready = false;
  Counter? editingCounter;
  Counter? viewingCounter;
  Note? editingNote;
  DateTime? editingNoteDate;
  final history = <List<int>>[];

  final nav = Nav();
  bool get canExit => history.isEmpty && screen == 0 && timeTab == 0;

  void readyUp() {
    ready = true;
    notifyListeners();
  }

  void go(int s, {int tab = 0}) {
    if (screen == s && timeTab == tab) return;
    history.add([screen, timeTab]);
    screen = s;
    timeTab = s == 2 ? tab : 0;
    notifyListeners();
  }

  void openCounterDetail(Counter counter) {
    history.add([screen, timeTab]);
    viewingCounter = counter;
    screen = 8;
    timeTab = 0;
    notifyListeners();
  }

  void openCounterEditor([Counter? counter]) {
    history.add([screen, timeTab]);
    editingCounter = counter;
    screen = 6;
    timeTab = 0;
    notifyListeners();
  }

  void openNoteEditor([Note? note, DateTime? date]) {
    history.add([screen, timeTab]);
    editingNote = note;
    editingNoteDate = date;
    screen = 7;
    timeTab = 0;
    notifyListeners();
  }

  void jump(int s, {int tab = 0}) {
    if (screen == s && timeTab == tab && history.isEmpty) return;
    history.clear();
    editingCounter = null;
    viewingCounter = null;
    editingNote = null;
    editingNoteDate = null;
    screen = s;
    timeTab = s == 2 ? tab : 0;
    notifyListeners();
  }

  void back() {
    if (screen == 2 && timeTab == 1) {
      timeTab = 0;
      notifyListeners();
      return;
    }
    if (history.isNotEmpty) {
      final p = history.removeLast();
      screen = p[0];
      timeTab = p[1];
      notifyListeners();
      return;
    }
    if (screen != 0) {
      screen = 0;
      timeTab = 0;
      editingCounter = null;
      viewingCounter = null;
      editingNote = null;
      editingNoteDate = null;
      notifyListeners();
    }
  }

  void setTimeTab(int v) {
    if (timeTab == v) return;
    timeTab = v;
    notifyListeners();
  }
}
