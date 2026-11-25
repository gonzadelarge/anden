import '../data/api/anden_server_api.dart';

/// Text for a timetable the server does not have, or null for any other error
/// (those mean "could not reach the server").
String? timetableNotice(Object error) {
  if (error is! AndenServerException) return null;
  return switch (error.code) {
    AndenServerException.noRoute => 'Sin horarios para este trayecto',
    AndenServerException.dateNotCovered => 'Horario aún no publicado para este día',
    _ => null,
  };
}
