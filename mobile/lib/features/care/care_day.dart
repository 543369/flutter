DateTime careDay(DateTime date) => DateTime(date.year, date.month, date.day);
bool careOnDay(String timestamp, DateTime day) =>
    careDay(DateTime.parse(timestamp).toLocal()) == careDay(day);
bool actionableCare(Map<String, dynamic> task) =>
    task['completed'] != true && task['cancelled'] != true;
