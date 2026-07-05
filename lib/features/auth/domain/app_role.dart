enum AppRole { select, owner, manager, staff }

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.select:
        return 'Select Role';
      case AppRole.owner:
        return 'Owner';
      case AppRole.manager:
        return 'Manager';
      case AppRole.staff:
        return 'Staff';
    }
  }

  String get storageValue {
    switch (this) {
      case AppRole.select:
        return 'select';
      case AppRole.owner:
        return 'owner';
      case AppRole.manager:
        return 'manager';
      case AppRole.staff:
        return 'staff';
    }
  }

  Duration get maxInactiveDuration {
    switch (this) {
      case AppRole.owner:
      case AppRole.manager:
        return const Duration(minutes: 20);
      case AppRole.staff:
        return const Duration(hours: 24);
      case AppRole.select:
        return Duration.zero;
    }
  }

  static AppRole fromStorage(String value) {
    switch (value) {
      case 'owner':
        return AppRole.owner;
      case 'manager':
        return AppRole.manager;
      case 'staff':
        return AppRole.staff;
      default:
        return AppRole.select;
    }
  }
}
