/// Toute donnée persistée possède un identifiant unique (UUID) et se
/// sérialise en JSON. Ce format JSON est celui qui sera échangé plus tard
/// avec le serveur (Raspberry Pi) : le garder stable et rétro-compatible.
abstract class Entity {
  String get id;
  Map<String, Object?> toJson();
}
