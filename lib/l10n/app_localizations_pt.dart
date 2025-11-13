// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Gestor';

  @override
  String get signIn => 'Iniciar sessão';

  @override
  String get emailOrUsername => 'Email ou Nome de Utilizador';

  @override
  String get password => 'Palavra-passe';

  @override
  String get required => 'Obrigatório';

  @override
  String get login => 'Entrar';

  @override
  String get loginFailed => 'Falha no login';

  @override
  String get noDevicesFound => 'Nenhum dispositivo encontrado';

  @override
  String get waitingForData => 'Aguardando dados...';

  @override
  String get total => 'Total';

  @override
  String get online => 'Ligados';

  @override
  String get offline => 'Desligados';

  @override
  String get searchDevices => 'Pesquisar dispositivos...';

  @override
  String get tryDifferentSearch => 'Tente um termo de pesquisa diferente';

  @override
  String get statusUnknown => 'DESCONHECIDO';

  @override
  String get justNow => 'Agora mesmo';

  @override
  String minutesAgo(int minutes) {
    return 'Há ${minutes}m';
  }

  @override
  String hoursAgo(int hours) {
    return 'Há ${hours}h';
  }

  @override
  String daysAgo(int days) {
    return 'Há ${days}d';
  }

  @override
  String get never => 'Nunca';

  @override
  String get speedNotAvailable => 'N/D';

  @override
  String speedKmh(int speed) {
    return '$speed km/h';
  }

  @override
  String get user => 'Utilizador';

  @override
  String get statistics => 'Estatísticas';

  @override
  String get devices => 'Dispositivos';

  @override
  String get active => 'Ativos';

  @override
  String get logout => 'Sair';

  @override
  String get logoutConfirmation => 'Tem a certeza que deseja sair?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get mapStyleMapbox => 'Mapbox';

  @override
  String get mapStyleGoogle => 'Google';

  @override
  String get mapStyleSatellite => 'Satélite';

  @override
  String get mapStyleDark => 'Escuro';

  @override
  String get mapStyleLight => 'Claro';

  @override
  String get loading => 'A carregar...';
}
