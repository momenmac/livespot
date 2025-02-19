String censorEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return email;

  final username = parts[0];
  final domain = parts[1];

  final censoredUsername = username.length > 3
      ? '${username.substring(0, 2)}${'•' * (username.length - 2)}'
      : username;

  return '$censoredUsername@$domain';
}
