import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../icons/icons.dart' as platform_icons;

/// Icons, colors and localized names for Traccar events.
class EventDisplay {
  EventDisplay._();

  static IconData icon(String type) {
    switch (type.toLowerCase()) {
      case 'ignitionon':
        return platform_icons.PlatformIcons.ignitionOn;
      case 'ignitionoff':
        return platform_icons.PlatformIcons.ignitionOff;
      case 'geofenceenter':
        return Icons.login;
      case 'geofenceexit':
        return Icons.logout;
      case 'alarm':
        return Icons.warning;
      case 'commandresult':
        return Icons.check_circle;
      case 'devicemoving':
      case 'tripstart':
        return Icons.play_arrow;
      case 'devicestopped':
      case 'tripend':
      case 'stopstart':
      case 'stopend':
        return Icons.stop;
      case 'deviceoverspeed':
        return Icons.speed;
      default:
        return Icons.event;
    }
  }

  static Color color(BuildContext context, String type) {
    final colors = Theme.of(context).colorScheme;
    switch (type.toLowerCase()) {
      case 'ignitionon':
      case 'devicemoving':
      case 'tripstart':
        return colors.tertiary;
      case 'ignitionoff':
      case 'devicestopped':
      case 'tripend':
      case 'stopstart':
      case 'stopend':
        return colors.error;
      default:
        return colors.primary;
    }
  }

  static String label(AppLocalizations l10n, Event event) {
    switch (event.type) {
      case 'alarm':
        final alarm = event.attributes?['alarm'] as String?;
        return alarm != null ? alarmLabel(l10n, alarm) : l10n.eventAlarm;
      case 'ignitionOn':
        return l10n.eventIgnitionOn;
      case 'ignitionOff':
        return l10n.eventIgnitionOff;
      case 'geofenceEnter':
        return l10n.eventGeofenceEnter;
      case 'geofenceExit':
        return l10n.eventGeofenceExit;
      case 'commandResult':
        return l10n.eventCommandResult;
      case 'deviceMoving':
        return l10n.eventDeviceMoving;
      case 'deviceStopped':
        return l10n.eventDeviceStopped;
      case 'deviceOverspeed':
        return l10n.eventDeviceOverspeed;
      case 'deviceOnline':
        return l10n.eventDeviceOnline;
      case 'deviceOffline':
        return l10n.eventDeviceOffline;
      case 'deviceUnknown':
        return l10n.eventDeviceUnknown;
      case 'deviceInactive':
        return l10n.eventDeviceInactive;
      case 'deviceFuelDrop':
        return l10n.eventDeviceFuelDrop;
      case 'deviceFuelIncrease':
        return l10n.eventDeviceFuelIncrease;
      case 'maintenance':
        return l10n.eventMaintenance;
      case 'textMessage':
        return l10n.eventTextMessage;
      case 'driverChanged':
        return l10n.eventDriverChanged;
      case 'media':
        return l10n.eventMedia;
      case 'queuedCommandSent':
        return l10n.eventQueuedCommandSent;
      default:
        return _humanize(event.type);
    }
  }

  static String alarmLabel(AppLocalizations l10n, String alarm) {
    switch (alarm) {
      case 'sos':
        return l10n.alarmSos;
      case 'powerCut':
        return l10n.alarmPowerCut;
      case 'powerRestored':
        return l10n.alarmPowerRestored;
      case 'powerOff':
        return l10n.alarmPowerOff;
      case 'powerOn':
        return l10n.alarmPowerOn;
      case 'lowBattery':
        return l10n.alarmLowBattery;
      case 'lowPower':
        return l10n.alarmLowPower;
      case 'overspeed':
        return l10n.alarmOverspeed;
      case 'vibration':
        return l10n.alarmVibration;
      case 'movement':
        return l10n.alarmMovement;
      case 'tow':
        return l10n.alarmTow;
      case 'tampering':
        return l10n.alarmTampering;
      case 'removing':
        return l10n.alarmRemoving;
      case 'accident':
        return l10n.alarmAccident;
      case 'fallDown':
        return l10n.alarmFallDown;
      case 'hardAcceleration':
        return l10n.alarmHardAcceleration;
      case 'hardBraking':
        return l10n.alarmHardBraking;
      case 'hardCornering':
        return l10n.alarmHardCornering;
      case 'fatigueDriving':
        return l10n.alarmFatigueDriving;
      case 'jamming':
        return l10n.alarmJamming;
      case 'gpsAntennaCut':
        return l10n.alarmGpsAntennaCut;
      case 'door':
        return l10n.alarmDoor;
      case 'idle':
        return l10n.alarmIdle;
      case 'general':
        return l10n.alarmGeneral;
      default:
        return '${l10n.eventAlarm}: ${_humanize(alarm)}';
    }
  }

  /// "highRpm" -> "High rpm"
  static String _humanize(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (m) => ' ${m[1]!.toLowerCase()}',
    );
    return spaced.isEmpty
        ? spaced
        : spaced[0].toUpperCase() + spaced.substring(1);
  }
}
