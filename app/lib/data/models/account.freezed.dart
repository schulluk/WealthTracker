// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Account {

 int get id; String get name; Broker get broker;@JsonKey(name: 'account_identifier') String? get accountIdentifier;@JsonKey(name: 'account_type') String get accountType; String get currency;@JsonKey(name: 'is_manual') bool get isManual;@JsonKey(name: 'sync_enabled') bool get syncEnabled; String get status;@JsonKey(name: 'last_sync_at') String? get lastSyncAt;@JsonKey(name: 'last_sync_error') String? get lastSyncError;@JsonKey(name: 'latest_snapshot') AccountSnapshot? get latestSnapshot;@JsonKey(name: 'created_at') String? get createdAt;@JsonKey(name: 'updated_at') String? get updatedAt;
/// Create a copy of Account
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountCopyWith<Account> get copyWith => _$AccountCopyWithImpl<Account>(this as Account, _$identity);

  /// Serializes this Account to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Account&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.broker, broker) || other.broker == broker)&&(identical(other.accountIdentifier, accountIdentifier) || other.accountIdentifier == accountIdentifier)&&(identical(other.accountType, accountType) || other.accountType == accountType)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.isManual, isManual) || other.isManual == isManual)&&(identical(other.syncEnabled, syncEnabled) || other.syncEnabled == syncEnabled)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastSyncAt, lastSyncAt) || other.lastSyncAt == lastSyncAt)&&(identical(other.lastSyncError, lastSyncError) || other.lastSyncError == lastSyncError)&&(identical(other.latestSnapshot, latestSnapshot) || other.latestSnapshot == latestSnapshot)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,broker,accountIdentifier,accountType,currency,isManual,syncEnabled,status,lastSyncAt,lastSyncError,latestSnapshot,createdAt,updatedAt);

@override
String toString() {
  return 'Account(id: $id, name: $name, broker: $broker, accountIdentifier: $accountIdentifier, accountType: $accountType, currency: $currency, isManual: $isManual, syncEnabled: $syncEnabled, status: $status, lastSyncAt: $lastSyncAt, lastSyncError: $lastSyncError, latestSnapshot: $latestSnapshot, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AccountCopyWith<$Res>  {
  factory $AccountCopyWith(Account value, $Res Function(Account) _then) = _$AccountCopyWithImpl;
@useResult
$Res call({
 int id, String name, Broker broker,@JsonKey(name: 'account_identifier') String? accountIdentifier,@JsonKey(name: 'account_type') String accountType, String currency,@JsonKey(name: 'is_manual') bool isManual,@JsonKey(name: 'sync_enabled') bool syncEnabled, String status,@JsonKey(name: 'last_sync_at') String? lastSyncAt,@JsonKey(name: 'last_sync_error') String? lastSyncError,@JsonKey(name: 'latest_snapshot') AccountSnapshot? latestSnapshot,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt
});


$BrokerCopyWith<$Res> get broker;$AccountSnapshotCopyWith<$Res>? get latestSnapshot;

}
/// @nodoc
class _$AccountCopyWithImpl<$Res>
    implements $AccountCopyWith<$Res> {
  _$AccountCopyWithImpl(this._self, this._then);

  final Account _self;
  final $Res Function(Account) _then;

/// Create a copy of Account
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? broker = null,Object? accountIdentifier = freezed,Object? accountType = null,Object? currency = null,Object? isManual = null,Object? syncEnabled = null,Object? status = null,Object? lastSyncAt = freezed,Object? lastSyncError = freezed,Object? latestSnapshot = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,broker: null == broker ? _self.broker : broker // ignore: cast_nullable_to_non_nullable
as Broker,accountIdentifier: freezed == accountIdentifier ? _self.accountIdentifier : accountIdentifier // ignore: cast_nullable_to_non_nullable
as String?,accountType: null == accountType ? _self.accountType : accountType // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,isManual: null == isManual ? _self.isManual : isManual // ignore: cast_nullable_to_non_nullable
as bool,syncEnabled: null == syncEnabled ? _self.syncEnabled : syncEnabled // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,lastSyncAt: freezed == lastSyncAt ? _self.lastSyncAt : lastSyncAt // ignore: cast_nullable_to_non_nullable
as String?,lastSyncError: freezed == lastSyncError ? _self.lastSyncError : lastSyncError // ignore: cast_nullable_to_non_nullable
as String?,latestSnapshot: freezed == latestSnapshot ? _self.latestSnapshot : latestSnapshot // ignore: cast_nullable_to_non_nullable
as AccountSnapshot?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Account
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BrokerCopyWith<$Res> get broker {
  
  return $BrokerCopyWith<$Res>(_self.broker, (value) {
    return _then(_self.copyWith(broker: value));
  });
}/// Create a copy of Account
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccountSnapshotCopyWith<$Res>? get latestSnapshot {
    if (_self.latestSnapshot == null) {
    return null;
  }

  return $AccountSnapshotCopyWith<$Res>(_self.latestSnapshot!, (value) {
    return _then(_self.copyWith(latestSnapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [Account].
extension AccountPatterns on Account {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Account value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Account() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Account value)  $default,){
final _that = this;
switch (_that) {
case _Account():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Account value)?  $default,){
final _that = this;
switch (_that) {
case _Account() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  Broker broker, @JsonKey(name: 'account_identifier')  String? accountIdentifier, @JsonKey(name: 'account_type')  String accountType,  String currency, @JsonKey(name: 'is_manual')  bool isManual, @JsonKey(name: 'sync_enabled')  bool syncEnabled,  String status, @JsonKey(name: 'last_sync_at')  String? lastSyncAt, @JsonKey(name: 'last_sync_error')  String? lastSyncError, @JsonKey(name: 'latest_snapshot')  AccountSnapshot? latestSnapshot, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Account() when $default != null:
return $default(_that.id,_that.name,_that.broker,_that.accountIdentifier,_that.accountType,_that.currency,_that.isManual,_that.syncEnabled,_that.status,_that.lastSyncAt,_that.lastSyncError,_that.latestSnapshot,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  Broker broker, @JsonKey(name: 'account_identifier')  String? accountIdentifier, @JsonKey(name: 'account_type')  String accountType,  String currency, @JsonKey(name: 'is_manual')  bool isManual, @JsonKey(name: 'sync_enabled')  bool syncEnabled,  String status, @JsonKey(name: 'last_sync_at')  String? lastSyncAt, @JsonKey(name: 'last_sync_error')  String? lastSyncError, @JsonKey(name: 'latest_snapshot')  AccountSnapshot? latestSnapshot, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Account():
return $default(_that.id,_that.name,_that.broker,_that.accountIdentifier,_that.accountType,_that.currency,_that.isManual,_that.syncEnabled,_that.status,_that.lastSyncAt,_that.lastSyncError,_that.latestSnapshot,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  Broker broker, @JsonKey(name: 'account_identifier')  String? accountIdentifier, @JsonKey(name: 'account_type')  String accountType,  String currency, @JsonKey(name: 'is_manual')  bool isManual, @JsonKey(name: 'sync_enabled')  bool syncEnabled,  String status, @JsonKey(name: 'last_sync_at')  String? lastSyncAt, @JsonKey(name: 'last_sync_error')  String? lastSyncError, @JsonKey(name: 'latest_snapshot')  AccountSnapshot? latestSnapshot, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Account() when $default != null:
return $default(_that.id,_that.name,_that.broker,_that.accountIdentifier,_that.accountType,_that.currency,_that.isManual,_that.syncEnabled,_that.status,_that.lastSyncAt,_that.lastSyncError,_that.latestSnapshot,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Account extends Account {
  const _Account({required this.id, required this.name, required this.broker, @JsonKey(name: 'account_identifier') this.accountIdentifier, @JsonKey(name: 'account_type') required this.accountType, required this.currency, @JsonKey(name: 'is_manual') required this.isManual, @JsonKey(name: 'sync_enabled') required this.syncEnabled, required this.status, @JsonKey(name: 'last_sync_at') this.lastSyncAt, @JsonKey(name: 'last_sync_error') this.lastSyncError, @JsonKey(name: 'latest_snapshot') this.latestSnapshot, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt}): super._();
  factory _Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);

@override final  int id;
@override final  String name;
@override final  Broker broker;
@override@JsonKey(name: 'account_identifier') final  String? accountIdentifier;
@override@JsonKey(name: 'account_type') final  String accountType;
@override final  String currency;
@override@JsonKey(name: 'is_manual') final  bool isManual;
@override@JsonKey(name: 'sync_enabled') final  bool syncEnabled;
@override final  String status;
@override@JsonKey(name: 'last_sync_at') final  String? lastSyncAt;
@override@JsonKey(name: 'last_sync_error') final  String? lastSyncError;
@override@JsonKey(name: 'latest_snapshot') final  AccountSnapshot? latestSnapshot;
@override@JsonKey(name: 'created_at') final  String? createdAt;
@override@JsonKey(name: 'updated_at') final  String? updatedAt;

/// Create a copy of Account
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountCopyWith<_Account> get copyWith => __$AccountCopyWithImpl<_Account>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Account&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.broker, broker) || other.broker == broker)&&(identical(other.accountIdentifier, accountIdentifier) || other.accountIdentifier == accountIdentifier)&&(identical(other.accountType, accountType) || other.accountType == accountType)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.isManual, isManual) || other.isManual == isManual)&&(identical(other.syncEnabled, syncEnabled) || other.syncEnabled == syncEnabled)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastSyncAt, lastSyncAt) || other.lastSyncAt == lastSyncAt)&&(identical(other.lastSyncError, lastSyncError) || other.lastSyncError == lastSyncError)&&(identical(other.latestSnapshot, latestSnapshot) || other.latestSnapshot == latestSnapshot)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,broker,accountIdentifier,accountType,currency,isManual,syncEnabled,status,lastSyncAt,lastSyncError,latestSnapshot,createdAt,updatedAt);

@override
String toString() {
  return 'Account(id: $id, name: $name, broker: $broker, accountIdentifier: $accountIdentifier, accountType: $accountType, currency: $currency, isManual: $isManual, syncEnabled: $syncEnabled, status: $status, lastSyncAt: $lastSyncAt, lastSyncError: $lastSyncError, latestSnapshot: $latestSnapshot, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AccountCopyWith<$Res> implements $AccountCopyWith<$Res> {
  factory _$AccountCopyWith(_Account value, $Res Function(_Account) _then) = __$AccountCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, Broker broker,@JsonKey(name: 'account_identifier') String? accountIdentifier,@JsonKey(name: 'account_type') String accountType, String currency,@JsonKey(name: 'is_manual') bool isManual,@JsonKey(name: 'sync_enabled') bool syncEnabled, String status,@JsonKey(name: 'last_sync_at') String? lastSyncAt,@JsonKey(name: 'last_sync_error') String? lastSyncError,@JsonKey(name: 'latest_snapshot') AccountSnapshot? latestSnapshot,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt
});


@override $BrokerCopyWith<$Res> get broker;@override $AccountSnapshotCopyWith<$Res>? get latestSnapshot;

}
/// @nodoc
class __$AccountCopyWithImpl<$Res>
    implements _$AccountCopyWith<$Res> {
  __$AccountCopyWithImpl(this._self, this._then);

  final _Account _self;
  final $Res Function(_Account) _then;

/// Create a copy of Account
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? broker = null,Object? accountIdentifier = freezed,Object? accountType = null,Object? currency = null,Object? isManual = null,Object? syncEnabled = null,Object? status = null,Object? lastSyncAt = freezed,Object? lastSyncError = freezed,Object? latestSnapshot = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Account(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,broker: null == broker ? _self.broker : broker // ignore: cast_nullable_to_non_nullable
as Broker,accountIdentifier: freezed == accountIdentifier ? _self.accountIdentifier : accountIdentifier // ignore: cast_nullable_to_non_nullable
as String?,accountType: null == accountType ? _self.accountType : accountType // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,isManual: null == isManual ? _self.isManual : isManual // ignore: cast_nullable_to_non_nullable
as bool,syncEnabled: null == syncEnabled ? _self.syncEnabled : syncEnabled // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,lastSyncAt: freezed == lastSyncAt ? _self.lastSyncAt : lastSyncAt // ignore: cast_nullable_to_non_nullable
as String?,lastSyncError: freezed == lastSyncError ? _self.lastSyncError : lastSyncError // ignore: cast_nullable_to_non_nullable
as String?,latestSnapshot: freezed == latestSnapshot ? _self.latestSnapshot : latestSnapshot // ignore: cast_nullable_to_non_nullable
as AccountSnapshot?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Account
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BrokerCopyWith<$Res> get broker {
  
  return $BrokerCopyWith<$Res>(_self.broker, (value) {
    return _then(_self.copyWith(broker: value));
  });
}/// Create a copy of Account
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccountSnapshotCopyWith<$Res>? get latestSnapshot {
    if (_self.latestSnapshot == null) {
    return null;
  }

  return $AccountSnapshotCopyWith<$Res>(_self.latestSnapshot!, (value) {
    return _then(_self.copyWith(latestSnapshot: value));
  });
}
}

// dart format on
