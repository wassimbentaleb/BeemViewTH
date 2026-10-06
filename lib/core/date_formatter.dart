// Formats anglais utilises dans l'app, sans ajouter un package pour deux formats.
class DateFormatter {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String date(DateTime value) {
    // Les dates de travail gardent le jour de calendrier fourni par l'API.
    return '${_months[value.month - 1]} ${value.day}, ${value.year}';
  }

  static String timestamp(DateTime value) {
    // Les instants created_at/updated_at sont affiches dans le fuseau du telephone.
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${date(local)}, $hour:$minute';
  }
}
