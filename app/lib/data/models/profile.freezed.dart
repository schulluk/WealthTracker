// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Profile {

@JsonKey(name: 'base_currency') String get baseCurrency;@JsonKey(name: 'auto_sync_enabled') bool get autoSyncEnabled;@JsonKey(name: 'send_weekly_report') bool get sendWeeklyReport;@JsonKey(name: 'default_chart_range') int get defaultChartRange;@JsonKey(name: 'default_chart_granularity') String get defaultChartGranularity;@JsonKey(name: 'push_notifications_enabled') bool get pushNotificationsEnabled;@JsonKey(name: 'push_weekly_report') bool get pushWeeklyReport;@JsonKey(name: 'sync_on_app_open') bool get syncOnAppOpen;@JsonKey(name: 'monthly_aggregation') String get monthlyAggregation;// Encryption status
@JsonKey(name: 'encryption_migrated') bool get encryptionMigrated;
/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileCopyWith<Profile> get copyWith => _$ProfileCopyWithImpl<Profile>(this as Profile, _$identity);

  /// Serializes this Profile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Profile&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.autoSyncEnabled, autoSyncEnabled) || other.autoSyncEnabled == autoSyncEnabled)&&(identical(other.sendWeeklyReport, sendWeeklyReport) || other.sendWeeklyReport == sendWeeklyReport)&&(identical(other.defaultChartRange, defaultChartRange) || other.defaultChartRange == defaultChartRange)&&(identical(other.defaultChartGranularity, defaultChartGranularity) || other.defaultChartGranularity == defaultChartGranularity)&&(identical(other.pushNotificationsEnabled, pushNotificationsEnabled) || other.pushNotificationsEnabled == pushNotificationsEnabled)&&(identical(other.pushWeeklyReport, pushWeeklyReport) || other.pushWeeklyReport == pushWeeklyReport)&&(identical(other.syncOnAppOpen, syncOnAppOpen) || other.syncOnAppOpen == syncOnAppOpen)&&(identical(other.monthlyAggregation, monthlyAggregation) || other.monthlyAggregation == monthlyAggregation)&&(identical(other.encryptionMigrated, encryptionMigrated) || other.encryptionMigrated == encryptionMigrated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,baseCurrency,autoSyncEnabled,sendWeeklyReport,defaultChartRange,defaultChartGranularity,pushNotificationsEnabled,pushWeeklyReport,syncOnAppOpen,monthlyAggregation,encryptionMigrated);

@override
String toString() {
  return 'Profile(baseCurrency: $baseCurrency, autoSyncEnabled: $autoSyncEnabled, sendWeeklyReport: $sendWeeklyReport, defaultChartRange: $defaultChartRange, defaultChartGranularity: $defaultChartGranularity, pushNotificationsEnabled: $pushNotificationsEnabled, pushWeeklyReport: $pushWeeklyReport, syncOnAppOpen: $syncOnAppOpen, monthlyAggregation: $monthlyAggregation, encryptionMigrated: $encryptionMigrated)';
}


}

/// @nodoc
abstract mixin class $ProfileCopyWith<$Res>  {
  factory $ProfileCopyWith(Profile value, $Res Function(Profile) _then) = _$ProfileCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'base_currency') String baseCurrency,@JsonKey(name: 'auto_sync_enabled') bool autoSyncEnabled,@JsonKey(name: 'send_weekly_report') bool sendWeeklyReport,@JsonKey(name: 'default_chart_range') int defaultChartRange,@JsonKey(name: 'default_chart_granularity') String defaultChartGranularity,@JsonKey(name: 'push_notifications_enabled') bool pushNotificationsEnabled,@JsonKey(name: 'push_weekly_report') bool pushWeeklyReport,@JsonKey(name: 'sync_on_app_open') bool syncOnAppOpen,@JsonKey(name: 'monthly_aggregation') String monthlyAggregation,@JsonKey(name: 'encryption_migrated') bool encryptionMigrated
});




}
/// @nodoc
class _$ProfileCopyWithImpl<$Res>
    implements $ProfileCopyWith<$Res> {
  _$ProfileCopyWithImpl(this._self, this._then);

  final Profile _self;
  final $Res Function(Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? baseCurrency = null,Object? autoSyncEnabled = null,Object? sendWeeklyReport = null,Object? defaultChartRange = null,Object? defaultChartGranularity = null,Object? pushNotificationsEnabled = null,Object? pushWeeklyReport = null,Object? syncOnAppOpen = null,Object? monthlyAggregation = null,Object? encryptionMigrated = null,}) {
  return _then(_self.copyWith(
baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,autoSyncEnabled: null == autoSyncEnabled ? _self.autoSyncEnabled : autoSyncEnabled // ignore: cast_nullable_to_non_nullable
as bool,sendWeeklyReport: null == sendWeeklyReport ? _self.sendWeeklyReport : sendWeeklyReport // ignore: cast_nullable_to_non_nullable
as bool,defaultChartRange: null == defaultChartRange ? _self.defaultChartRange : defaultChartRange // ignore: cast_nullable_to_non_nullable
as int,defaultChartGranularity: null == defaultChartGranularity ? _self.defaultChartGranularity : defaultChartGranularity // ignore: cast_nullable_to_non_nullable
as String,pushNotificationsEnabled: null == pushNotificationsEnabled ? _self.pushNotificationsEnabled : pushNotificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,pushWeeklyReport: null == pushWeeklyReport ? _self.pushWeeklyReport : pushWeeklyReport // ignore: cast_nullable_to_non_nullable
as bool,syncOnAppOpen: null == syncOnAppOpen ? _self.syncOnAppOpen : syncOnAppOpen // ignore: cast_nullable_to_non_nullable
as bool,monthlyAggregation: null == monthlyAggregation ? _self.monthlyAggregation : monthlyAggregation // ignore: cast_nullable_to_non_nullable
as String,encryptionMigrated: null == encryptionMigrated ? _self.encryptionMigrated : encryptionMigrated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Profile].
extension ProfilePatterns on Profile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Profile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Profile value)  $default,){
final _that = this;
switch (_that) {
case _Profile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Profile value)?  $default,){
final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'auto_sync_enabled')  bool autoSyncEnabled, @JsonKey(name: 'send_weekly_report')  bool sendWeeklyReport, @JsonKey(name: 'default_chart_range')  int defaultChartRange, @JsonKey(name: 'default_chart_granularity')  String defaultChartGranularity, @JsonKey(name: 'push_notifications_enabled')  bool pushNotificationsEnabled, @JsonKey(name: 'push_weekly_report')  bool pushWeeklyReport, @JsonKey(name: 'sync_on_app_open')  bool syncOnAppOpen, @JsonKey(name: 'monthly_aggregation')  String monthlyAggregation, @JsonKey(name: 'encryption_migrated')  bool encryptionMigrated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that.baseCurrency,_that.autoSyncEnabled,_that.sendWeeklyReport,_that.defaultChartRange,_that.defaultChartGranularity,_that.pushNotificationsEnabled,_that.pushWeeklyReport,_that.syncOnAppOpen,_that.monthlyAggregation,_that.encryptionMigrated);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'auto_sync_enabled')  bool autoSyncEnabled, @JsonKey(name: 'send_weekly_report')  bool sendWeeklyReport, @JsonKey(name: 'default_chart_range')  int defaultChartRange, @JsonKey(name: 'default_chart_granularity')  String defaultChartGranularity, @JsonKey(name: 'push_notifications_enabled')  bool pushNotificationsEnabled, @JsonKey(name: 'push_weekly_report')  bool pushWeeklyReport, @JsonKey(name: 'sync_on_app_open')  bool syncOnAppOpen, @JsonKey(name: 'monthly_aggregation')  String monthlyAggregation, @JsonKey(name: 'encryption_migrated')  bool encryptionMigrated)  $default,) {final _that = this;
switch (_that) {
case _Profile():
return $default(_that.baseCurrency,_that.autoSyncEnabled,_that.sendWeeklyReport,_that.defaultChartRange,_that.defaultChartGranularity,_that.pushNotificationsEnabled,_that.pushWeeklyReport,_that.syncOnAppOpen,_that.monthlyAggregation,_that.encryptionMigrated);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'auto_sync_enabled')  bool autoSyncEnabled, @JsonKey(name: 'send_weekly_report')  bool sendWeeklyReport, @JsonKey(name: 'default_chart_range')  int defaultChartRange, @JsonKey(name: 'default_chart_granularity')  String defaultChartGranularity, @JsonKey(name: 'push_notifications_enabled')  bool pushNotificationsEnabled, @JsonKey(name: 'push_weekly_report')  bool pushWeeklyReport, @JsonKey(name: 'sync_on_app_open')  bool syncOnAppOpen, @JsonKey(name: 'monthly_aggregation')  String monthlyAggregation, @JsonKey(name: 'encryption_migrated')  bool encryptionMigrated)?  $default,) {final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that.baseCurrency,_that.autoSyncEnabled,_that.sendWeeklyReport,_that.defaultChartRange,_that.defaultChartGranularity,_that.pushNotificationsEnabled,_that.pushWeeklyReport,_that.syncOnAppOpen,_that.monthlyAggregation,_that.encryptionMigrated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Profile implements Profile {
  const _Profile({@JsonKey(name: 'base_currency') required this.baseCurrency, @JsonKey(name: 'auto_sync_enabled') required this.autoSyncEnabled, @JsonKey(name: 'send_weekly_report') required this.sendWeeklyReport, @JsonKey(name: 'default_chart_range') required this.defaultChartRange, @JsonKey(name: 'default_chart_granularity') required this.defaultChartGranularity, @JsonKey(name: 'push_notifications_enabled') this.pushNotificationsEnabled = true, @JsonKey(name: 'push_weekly_report') this.pushWeeklyReport = false, @JsonKey(name: 'sync_on_app_open') this.syncOnAppOpen = false, @JsonKey(name: 'monthly_aggregation') this.monthlyAggregation = 'last', @JsonKey(name: 'encryption_migrated') this.encryptionMigrated = false});
  factory _Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);

@override@JsonKey(name: 'base_currency') final  String baseCurrency;
@override@JsonKey(name: 'auto_sync_enabled') final  bool autoSyncEnabled;
@override@JsonKey(name: 'send_weekly_report') final  bool sendWeeklyReport;
@override@JsonKey(name: 'default_chart_range') final  int defaultChartRange;
@override@JsonKey(name: 'default_chart_granularity') final  String defaultChartGranularity;
@override@JsonKey(name: 'push_notifications_enabled') final  bool pushNotificationsEnabled;
@override@JsonKey(name: 'push_weekly_report') final  bool pushWeeklyReport;
@override@JsonKey(name: 'sync_on_app_open') final  bool syncOnAppOpen;
@override@JsonKey(name: 'monthly_aggregation') final  String monthlyAggregation;
// Encryption status
@override@JsonKey(name: 'encryption_migrated') final  bool encryptionMigrated;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileCopyWith<_Profile> get copyWith => __$ProfileCopyWithImpl<_Profile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Profile&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.autoSyncEnabled, autoSyncEnabled) || other.autoSyncEnabled == autoSyncEnabled)&&(identical(other.sendWeeklyReport, sendWeeklyReport) || other.sendWeeklyReport == sendWeeklyReport)&&(identical(other.defaultChartRange, defaultChartRange) || other.defaultChartRange == defaultChartRange)&&(identical(other.defaultChartGranularity, defaultChartGranularity) || other.defaultChartGranularity == defaultChartGranularity)&&(identical(other.pushNotificationsEnabled, pushNotificationsEnabled) || other.pushNotificationsEnabled == pushNotificationsEnabled)&&(identical(other.pushWeeklyReport, pushWeeklyReport) || other.pushWeeklyReport == pushWeeklyReport)&&(identical(other.syncOnAppOpen, syncOnAppOpen) || other.syncOnAppOpen == syncOnAppOpen)&&(identical(other.monthlyAggregation, monthlyAggregation) || other.monthlyAggregation == monthlyAggregation)&&(identical(other.encryptionMigrated, encryptionMigrated) || other.encryptionMigrated == encryptionMigrated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,baseCurrency,autoSyncEnabled,sendWeeklyReport,defaultChartRange,defaultChartGranularity,pushNotificationsEnabled,pushWeeklyReport,syncOnAppOpen,monthlyAggregation,encryptionMigrated);

@override
String toString() {
  return 'Profile(baseCurrency: $baseCurrency, autoSyncEnabled: $autoSyncEnabled, sendWeeklyReport: $sendWeeklyReport, defaultChartRange: $defaultChartRange, defaultChartGranularity: $defaultChartGranularity, pushNotificationsEnabled: $pushNotificationsEnabled, pushWeeklyReport: $pushWeeklyReport, syncOnAppOpen: $syncOnAppOpen, monthlyAggregation: $monthlyAggregation, encryptionMigrated: $encryptionMigrated)';
}


}

/// @nodoc
abstract mixin class _$ProfileCopyWith<$Res> implements $ProfileCopyWith<$Res> {
  factory _$ProfileCopyWith(_Profile value, $Res Function(_Profile) _then) = __$ProfileCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'base_currency') String baseCurrency,@JsonKey(name: 'auto_sync_enabled') bool autoSyncEnabled,@JsonKey(name: 'send_weekly_report') bool sendWeeklyReport,@JsonKey(name: 'default_chart_range') int defaultChartRange,@JsonKey(name: 'default_chart_granularity') String defaultChartGranularity,@JsonKey(name: 'push_notifications_enabled') bool pushNotificationsEnabled,@JsonKey(name: 'push_weekly_report') bool pushWeeklyReport,@JsonKey(name: 'sync_on_app_open') bool syncOnAppOpen,@JsonKey(name: 'monthly_aggregation') String monthlyAggregation,@JsonKey(name: 'encryption_migrated') bool encryptionMigrated
});




}
/// @nodoc
class __$ProfileCopyWithImpl<$Res>
    implements _$ProfileCopyWith<$Res> {
  __$ProfileCopyWithImpl(this._self, this._then);

  final _Profile _self;
  final $Res Function(_Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? baseCurrency = null,Object? autoSyncEnabled = null,Object? sendWeeklyReport = null,Object? defaultChartRange = null,Object? defaultChartGranularity = null,Object? pushNotificationsEnabled = null,Object? pushWeeklyReport = null,Object? syncOnAppOpen = null,Object? monthlyAggregation = null,Object? encryptionMigrated = null,}) {
  return _then(_Profile(
baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,autoSyncEnabled: null == autoSyncEnabled ? _self.autoSyncEnabled : autoSyncEnabled // ignore: cast_nullable_to_non_nullable
as bool,sendWeeklyReport: null == sendWeeklyReport ? _self.sendWeeklyReport : sendWeeklyReport // ignore: cast_nullable_to_non_nullable
as bool,defaultChartRange: null == defaultChartRange ? _self.defaultChartRange : defaultChartRange // ignore: cast_nullable_to_non_nullable
as int,defaultChartGranularity: null == defaultChartGranularity ? _self.defaultChartGranularity : defaultChartGranularity // ignore: cast_nullable_to_non_nullable
as String,pushNotificationsEnabled: null == pushNotificationsEnabled ? _self.pushNotificationsEnabled : pushNotificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,pushWeeklyReport: null == pushWeeklyReport ? _self.pushWeeklyReport : pushWeeklyReport // ignore: cast_nullable_to_non_nullable
as bool,syncOnAppOpen: null == syncOnAppOpen ? _self.syncOnAppOpen : syncOnAppOpen // ignore: cast_nullable_to_non_nullable
as bool,monthlyAggregation: null == monthlyAggregation ? _self.monthlyAggregation : monthlyAggregation // ignore: cast_nullable_to_non_nullable
as String,encryptionMigrated: null == encryptionMigrated ? _self.encryptionMigrated : encryptionMigrated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
