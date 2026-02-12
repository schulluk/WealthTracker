// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Profile _$ProfileFromJson(Map<String, dynamic> json) {
  return _Profile.fromJson(json);
}

/// @nodoc
mixin _$Profile {
  @JsonKey(name: 'base_currency')
  String get baseCurrency => throw _privateConstructorUsedError;
  @JsonKey(name: 'auto_sync_enabled')
  bool get autoSyncEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'send_weekly_report')
  bool get sendWeeklyReport => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_chart_range')
  int get defaultChartRange => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_chart_granularity')
  String get defaultChartGranularity => throw _privateConstructorUsedError;
  @JsonKey(name: 'push_notifications_enabled')
  bool get pushNotificationsEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'push_weekly_report')
  bool get pushWeeklyReport => throw _privateConstructorUsedError;
  @JsonKey(name: 'sync_on_app_open')
  bool get syncOnAppOpen => throw _privateConstructorUsedError; // Encryption status
  @JsonKey(name: 'encryption_migrated')
  bool get encryptionMigrated => throw _privateConstructorUsedError;

  /// Serializes this Profile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileCopyWith<Profile> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileCopyWith<$Res> {
  factory $ProfileCopyWith(Profile value, $Res Function(Profile) then) =
      _$ProfileCopyWithImpl<$Res, Profile>;
  @useResult
  $Res call({
    @JsonKey(name: 'base_currency') String baseCurrency,
    @JsonKey(name: 'auto_sync_enabled') bool autoSyncEnabled,
    @JsonKey(name: 'send_weekly_report') bool sendWeeklyReport,
    @JsonKey(name: 'default_chart_range') int defaultChartRange,
    @JsonKey(name: 'default_chart_granularity') String defaultChartGranularity,
    @JsonKey(name: 'push_notifications_enabled') bool pushNotificationsEnabled,
    @JsonKey(name: 'push_weekly_report') bool pushWeeklyReport,
    @JsonKey(name: 'sync_on_app_open') bool syncOnAppOpen,
    @JsonKey(name: 'encryption_migrated') bool encryptionMigrated,
  });
}

/// @nodoc
class _$ProfileCopyWithImpl<$Res, $Val extends Profile>
    implements $ProfileCopyWith<$Res> {
  _$ProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseCurrency = null,
    Object? autoSyncEnabled = null,
    Object? sendWeeklyReport = null,
    Object? defaultChartRange = null,
    Object? defaultChartGranularity = null,
    Object? pushNotificationsEnabled = null,
    Object? pushWeeklyReport = null,
    Object? syncOnAppOpen = null,
    Object? encryptionMigrated = null,
  }) {
    return _then(
      _value.copyWith(
            baseCurrency: null == baseCurrency
                ? _value.baseCurrency
                : baseCurrency // ignore: cast_nullable_to_non_nullable
                      as String,
            autoSyncEnabled: null == autoSyncEnabled
                ? _value.autoSyncEnabled
                : autoSyncEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            sendWeeklyReport: null == sendWeeklyReport
                ? _value.sendWeeklyReport
                : sendWeeklyReport // ignore: cast_nullable_to_non_nullable
                      as bool,
            defaultChartRange: null == defaultChartRange
                ? _value.defaultChartRange
                : defaultChartRange // ignore: cast_nullable_to_non_nullable
                      as int,
            defaultChartGranularity: null == defaultChartGranularity
                ? _value.defaultChartGranularity
                : defaultChartGranularity // ignore: cast_nullable_to_non_nullable
                      as String,
            pushNotificationsEnabled: null == pushNotificationsEnabled
                ? _value.pushNotificationsEnabled
                : pushNotificationsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            pushWeeklyReport: null == pushWeeklyReport
                ? _value.pushWeeklyReport
                : pushWeeklyReport // ignore: cast_nullable_to_non_nullable
                      as bool,
            syncOnAppOpen: null == syncOnAppOpen
                ? _value.syncOnAppOpen
                : syncOnAppOpen // ignore: cast_nullable_to_non_nullable
                      as bool,
            encryptionMigrated: null == encryptionMigrated
                ? _value.encryptionMigrated
                : encryptionMigrated // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProfileImplCopyWith<$Res> implements $ProfileCopyWith<$Res> {
  factory _$$ProfileImplCopyWith(
    _$ProfileImpl value,
    $Res Function(_$ProfileImpl) then,
  ) = __$$ProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'base_currency') String baseCurrency,
    @JsonKey(name: 'auto_sync_enabled') bool autoSyncEnabled,
    @JsonKey(name: 'send_weekly_report') bool sendWeeklyReport,
    @JsonKey(name: 'default_chart_range') int defaultChartRange,
    @JsonKey(name: 'default_chart_granularity') String defaultChartGranularity,
    @JsonKey(name: 'push_notifications_enabled') bool pushNotificationsEnabled,
    @JsonKey(name: 'push_weekly_report') bool pushWeeklyReport,
    @JsonKey(name: 'sync_on_app_open') bool syncOnAppOpen,
    @JsonKey(name: 'encryption_migrated') bool encryptionMigrated,
  });
}

/// @nodoc
class __$$ProfileImplCopyWithImpl<$Res>
    extends _$ProfileCopyWithImpl<$Res, _$ProfileImpl>
    implements _$$ProfileImplCopyWith<$Res> {
  __$$ProfileImplCopyWithImpl(
    _$ProfileImpl _value,
    $Res Function(_$ProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseCurrency = null,
    Object? autoSyncEnabled = null,
    Object? sendWeeklyReport = null,
    Object? defaultChartRange = null,
    Object? defaultChartGranularity = null,
    Object? pushNotificationsEnabled = null,
    Object? pushWeeklyReport = null,
    Object? syncOnAppOpen = null,
    Object? encryptionMigrated = null,
  }) {
    return _then(
      _$ProfileImpl(
        baseCurrency: null == baseCurrency
            ? _value.baseCurrency
            : baseCurrency // ignore: cast_nullable_to_non_nullable
                  as String,
        autoSyncEnabled: null == autoSyncEnabled
            ? _value.autoSyncEnabled
            : autoSyncEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        sendWeeklyReport: null == sendWeeklyReport
            ? _value.sendWeeklyReport
            : sendWeeklyReport // ignore: cast_nullable_to_non_nullable
                  as bool,
        defaultChartRange: null == defaultChartRange
            ? _value.defaultChartRange
            : defaultChartRange // ignore: cast_nullable_to_non_nullable
                  as int,
        defaultChartGranularity: null == defaultChartGranularity
            ? _value.defaultChartGranularity
            : defaultChartGranularity // ignore: cast_nullable_to_non_nullable
                  as String,
        pushNotificationsEnabled: null == pushNotificationsEnabled
            ? _value.pushNotificationsEnabled
            : pushNotificationsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        pushWeeklyReport: null == pushWeeklyReport
            ? _value.pushWeeklyReport
            : pushWeeklyReport // ignore: cast_nullable_to_non_nullable
                  as bool,
        syncOnAppOpen: null == syncOnAppOpen
            ? _value.syncOnAppOpen
            : syncOnAppOpen // ignore: cast_nullable_to_non_nullable
                  as bool,
        encryptionMigrated: null == encryptionMigrated
            ? _value.encryptionMigrated
            : encryptionMigrated // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProfileImpl implements _Profile {
  const _$ProfileImpl({
    @JsonKey(name: 'base_currency') required this.baseCurrency,
    @JsonKey(name: 'auto_sync_enabled') required this.autoSyncEnabled,
    @JsonKey(name: 'send_weekly_report') required this.sendWeeklyReport,
    @JsonKey(name: 'default_chart_range') required this.defaultChartRange,
    @JsonKey(name: 'default_chart_granularity')
    required this.defaultChartGranularity,
    @JsonKey(name: 'push_notifications_enabled')
    this.pushNotificationsEnabled = true,
    @JsonKey(name: 'push_weekly_report') this.pushWeeklyReport = false,
    @JsonKey(name: 'sync_on_app_open') this.syncOnAppOpen = false,
    @JsonKey(name: 'encryption_migrated') this.encryptionMigrated = false,
  });

  factory _$ProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProfileImplFromJson(json);

  @override
  @JsonKey(name: 'base_currency')
  final String baseCurrency;
  @override
  @JsonKey(name: 'auto_sync_enabled')
  final bool autoSyncEnabled;
  @override
  @JsonKey(name: 'send_weekly_report')
  final bool sendWeeklyReport;
  @override
  @JsonKey(name: 'default_chart_range')
  final int defaultChartRange;
  @override
  @JsonKey(name: 'default_chart_granularity')
  final String defaultChartGranularity;
  @override
  @JsonKey(name: 'push_notifications_enabled')
  final bool pushNotificationsEnabled;
  @override
  @JsonKey(name: 'push_weekly_report')
  final bool pushWeeklyReport;
  @override
  @JsonKey(name: 'sync_on_app_open')
  final bool syncOnAppOpen;
  // Encryption status
  @override
  @JsonKey(name: 'encryption_migrated')
  final bool encryptionMigrated;

  @override
  String toString() {
    return 'Profile(baseCurrency: $baseCurrency, autoSyncEnabled: $autoSyncEnabled, sendWeeklyReport: $sendWeeklyReport, defaultChartRange: $defaultChartRange, defaultChartGranularity: $defaultChartGranularity, pushNotificationsEnabled: $pushNotificationsEnabled, pushWeeklyReport: $pushWeeklyReport, syncOnAppOpen: $syncOnAppOpen, encryptionMigrated: $encryptionMigrated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileImpl &&
            (identical(other.baseCurrency, baseCurrency) ||
                other.baseCurrency == baseCurrency) &&
            (identical(other.autoSyncEnabled, autoSyncEnabled) ||
                other.autoSyncEnabled == autoSyncEnabled) &&
            (identical(other.sendWeeklyReport, sendWeeklyReport) ||
                other.sendWeeklyReport == sendWeeklyReport) &&
            (identical(other.defaultChartRange, defaultChartRange) ||
                other.defaultChartRange == defaultChartRange) &&
            (identical(
                  other.defaultChartGranularity,
                  defaultChartGranularity,
                ) ||
                other.defaultChartGranularity == defaultChartGranularity) &&
            (identical(
                  other.pushNotificationsEnabled,
                  pushNotificationsEnabled,
                ) ||
                other.pushNotificationsEnabled == pushNotificationsEnabled) &&
            (identical(other.pushWeeklyReport, pushWeeklyReport) ||
                other.pushWeeklyReport == pushWeeklyReport) &&
            (identical(other.syncOnAppOpen, syncOnAppOpen) ||
                other.syncOnAppOpen == syncOnAppOpen) &&
            (identical(other.encryptionMigrated, encryptionMigrated) ||
                other.encryptionMigrated == encryptionMigrated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    baseCurrency,
    autoSyncEnabled,
    sendWeeklyReport,
    defaultChartRange,
    defaultChartGranularity,
    pushNotificationsEnabled,
    pushWeeklyReport,
    syncOnAppOpen,
    encryptionMigrated,
  );

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileImplCopyWith<_$ProfileImpl> get copyWith =>
      __$$ProfileImplCopyWithImpl<_$ProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProfileImplToJson(this);
  }
}

abstract class _Profile implements Profile {
  const factory _Profile({
    @JsonKey(name: 'base_currency') required final String baseCurrency,
    @JsonKey(name: 'auto_sync_enabled') required final bool autoSyncEnabled,
    @JsonKey(name: 'send_weekly_report') required final bool sendWeeklyReport,
    @JsonKey(name: 'default_chart_range') required final int defaultChartRange,
    @JsonKey(name: 'default_chart_granularity')
    required final String defaultChartGranularity,
    @JsonKey(name: 'push_notifications_enabled')
    final bool pushNotificationsEnabled,
    @JsonKey(name: 'push_weekly_report') final bool pushWeeklyReport,
    @JsonKey(name: 'sync_on_app_open') final bool syncOnAppOpen,
    @JsonKey(name: 'encryption_migrated') final bool encryptionMigrated,
  }) = _$ProfileImpl;

  factory _Profile.fromJson(Map<String, dynamic> json) = _$ProfileImpl.fromJson;

  @override
  @JsonKey(name: 'base_currency')
  String get baseCurrency;
  @override
  @JsonKey(name: 'auto_sync_enabled')
  bool get autoSyncEnabled;
  @override
  @JsonKey(name: 'send_weekly_report')
  bool get sendWeeklyReport;
  @override
  @JsonKey(name: 'default_chart_range')
  int get defaultChartRange;
  @override
  @JsonKey(name: 'default_chart_granularity')
  String get defaultChartGranularity;
  @override
  @JsonKey(name: 'push_notifications_enabled')
  bool get pushNotificationsEnabled;
  @override
  @JsonKey(name: 'push_weekly_report')
  bool get pushWeeklyReport;
  @override
  @JsonKey(name: 'sync_on_app_open')
  bool get syncOnAppOpen; // Encryption status
  @override
  @JsonKey(name: 'encryption_migrated')
  bool get encryptionMigrated;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileImplCopyWith<_$ProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
