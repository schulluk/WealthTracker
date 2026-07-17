// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountSnapshot {

 int get id; String get balance; String get currency;@JsonKey(name: 'balance_base_currency') String? get balanceBaseCurrency;@JsonKey(name: 'base_currency') String? get baseCurrency;@JsonKey(name: 'snapshot_date') String get snapshotDate;@JsonKey(name: 'snapshot_source') String? get snapshotSource;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of AccountSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountSnapshotCopyWith<AccountSnapshot> get copyWith => _$AccountSnapshotCopyWithImpl<AccountSnapshot>(this as AccountSnapshot, _$identity);

  /// Serializes this AccountSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountSnapshot&&(identical(other.id, id) || other.id == id)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.balanceBaseCurrency, balanceBaseCurrency) || other.balanceBaseCurrency == balanceBaseCurrency)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.snapshotDate, snapshotDate) || other.snapshotDate == snapshotDate)&&(identical(other.snapshotSource, snapshotSource) || other.snapshotSource == snapshotSource)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,balance,currency,balanceBaseCurrency,baseCurrency,snapshotDate,snapshotSource,createdAt);

@override
String toString() {
  return 'AccountSnapshot(id: $id, balance: $balance, currency: $currency, balanceBaseCurrency: $balanceBaseCurrency, baseCurrency: $baseCurrency, snapshotDate: $snapshotDate, snapshotSource: $snapshotSource, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $AccountSnapshotCopyWith<$Res>  {
  factory $AccountSnapshotCopyWith(AccountSnapshot value, $Res Function(AccountSnapshot) _then) = _$AccountSnapshotCopyWithImpl;
@useResult
$Res call({
 int id, String balance, String currency,@JsonKey(name: 'balance_base_currency') String? balanceBaseCurrency,@JsonKey(name: 'base_currency') String? baseCurrency,@JsonKey(name: 'snapshot_date') String snapshotDate,@JsonKey(name: 'snapshot_source') String? snapshotSource,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$AccountSnapshotCopyWithImpl<$Res>
    implements $AccountSnapshotCopyWith<$Res> {
  _$AccountSnapshotCopyWithImpl(this._self, this._then);

  final AccountSnapshot _self;
  final $Res Function(AccountSnapshot) _then;

/// Create a copy of AccountSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? balance = null,Object? currency = null,Object? balanceBaseCurrency = freezed,Object? baseCurrency = freezed,Object? snapshotDate = null,Object? snapshotSource = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,balanceBaseCurrency: freezed == balanceBaseCurrency ? _self.balanceBaseCurrency : balanceBaseCurrency // ignore: cast_nullable_to_non_nullable
as String?,baseCurrency: freezed == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String?,snapshotDate: null == snapshotDate ? _self.snapshotDate : snapshotDate // ignore: cast_nullable_to_non_nullable
as String,snapshotSource: freezed == snapshotSource ? _self.snapshotSource : snapshotSource // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountSnapshot].
extension AccountSnapshotPatterns on AccountSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _AccountSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _AccountSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String balance,  String currency, @JsonKey(name: 'balance_base_currency')  String? balanceBaseCurrency, @JsonKey(name: 'base_currency')  String? baseCurrency, @JsonKey(name: 'snapshot_date')  String snapshotDate, @JsonKey(name: 'snapshot_source')  String? snapshotSource, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountSnapshot() when $default != null:
return $default(_that.id,_that.balance,_that.currency,_that.balanceBaseCurrency,_that.baseCurrency,_that.snapshotDate,_that.snapshotSource,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String balance,  String currency, @JsonKey(name: 'balance_base_currency')  String? balanceBaseCurrency, @JsonKey(name: 'base_currency')  String? baseCurrency, @JsonKey(name: 'snapshot_date')  String snapshotDate, @JsonKey(name: 'snapshot_source')  String? snapshotSource, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _AccountSnapshot():
return $default(_that.id,_that.balance,_that.currency,_that.balanceBaseCurrency,_that.baseCurrency,_that.snapshotDate,_that.snapshotSource,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String balance,  String currency, @JsonKey(name: 'balance_base_currency')  String? balanceBaseCurrency, @JsonKey(name: 'base_currency')  String? baseCurrency, @JsonKey(name: 'snapshot_date')  String snapshotDate, @JsonKey(name: 'snapshot_source')  String? snapshotSource, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _AccountSnapshot() when $default != null:
return $default(_that.id,_that.balance,_that.currency,_that.balanceBaseCurrency,_that.baseCurrency,_that.snapshotDate,_that.snapshotSource,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountSnapshot implements AccountSnapshot {
  const _AccountSnapshot({required this.id, required this.balance, required this.currency, @JsonKey(name: 'balance_base_currency') this.balanceBaseCurrency, @JsonKey(name: 'base_currency') this.baseCurrency, @JsonKey(name: 'snapshot_date') required this.snapshotDate, @JsonKey(name: 'snapshot_source') this.snapshotSource, @JsonKey(name: 'created_at') this.createdAt});
  factory _AccountSnapshot.fromJson(Map<String, dynamic> json) => _$AccountSnapshotFromJson(json);

@override final  int id;
@override final  String balance;
@override final  String currency;
@override@JsonKey(name: 'balance_base_currency') final  String? balanceBaseCurrency;
@override@JsonKey(name: 'base_currency') final  String? baseCurrency;
@override@JsonKey(name: 'snapshot_date') final  String snapshotDate;
@override@JsonKey(name: 'snapshot_source') final  String? snapshotSource;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of AccountSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountSnapshotCopyWith<_AccountSnapshot> get copyWith => __$AccountSnapshotCopyWithImpl<_AccountSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountSnapshot&&(identical(other.id, id) || other.id == id)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.balanceBaseCurrency, balanceBaseCurrency) || other.balanceBaseCurrency == balanceBaseCurrency)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.snapshotDate, snapshotDate) || other.snapshotDate == snapshotDate)&&(identical(other.snapshotSource, snapshotSource) || other.snapshotSource == snapshotSource)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,balance,currency,balanceBaseCurrency,baseCurrency,snapshotDate,snapshotSource,createdAt);

@override
String toString() {
  return 'AccountSnapshot(id: $id, balance: $balance, currency: $currency, balanceBaseCurrency: $balanceBaseCurrency, baseCurrency: $baseCurrency, snapshotDate: $snapshotDate, snapshotSource: $snapshotSource, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AccountSnapshotCopyWith<$Res> implements $AccountSnapshotCopyWith<$Res> {
  factory _$AccountSnapshotCopyWith(_AccountSnapshot value, $Res Function(_AccountSnapshot) _then) = __$AccountSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int id, String balance, String currency,@JsonKey(name: 'balance_base_currency') String? balanceBaseCurrency,@JsonKey(name: 'base_currency') String? baseCurrency,@JsonKey(name: 'snapshot_date') String snapshotDate,@JsonKey(name: 'snapshot_source') String? snapshotSource,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$AccountSnapshotCopyWithImpl<$Res>
    implements _$AccountSnapshotCopyWith<$Res> {
  __$AccountSnapshotCopyWithImpl(this._self, this._then);

  final _AccountSnapshot _self;
  final $Res Function(_AccountSnapshot) _then;

/// Create a copy of AccountSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? balance = null,Object? currency = null,Object? balanceBaseCurrency = freezed,Object? baseCurrency = freezed,Object? snapshotDate = null,Object? snapshotSource = freezed,Object? createdAt = freezed,}) {
  return _then(_AccountSnapshot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,balanceBaseCurrency: freezed == balanceBaseCurrency ? _self.balanceBaseCurrency : balanceBaseCurrency // ignore: cast_nullable_to_non_nullable
as String?,baseCurrency: freezed == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String?,snapshotDate: null == snapshotDate ? _self.snapshotDate : snapshotDate // ignore: cast_nullable_to_non_nullable
as String,snapshotSource: freezed == snapshotSource ? _self.snapshotSource : snapshotSource // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
