// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wealth_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WealthSummary {

@JsonKey(name: 'total_wealth') double get totalWealth;@JsonKey(name: 'base_currency') String get baseCurrency;@JsonKey(name: 'account_count') int get accountCount;
/// Create a copy of WealthSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WealthSummaryCopyWith<WealthSummary> get copyWith => _$WealthSummaryCopyWithImpl<WealthSummary>(this as WealthSummary, _$identity);

  /// Serializes this WealthSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WealthSummary&&(identical(other.totalWealth, totalWealth) || other.totalWealth == totalWealth)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.accountCount, accountCount) || other.accountCount == accountCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalWealth,baseCurrency,accountCount);

@override
String toString() {
  return 'WealthSummary(totalWealth: $totalWealth, baseCurrency: $baseCurrency, accountCount: $accountCount)';
}


}

/// @nodoc
abstract mixin class $WealthSummaryCopyWith<$Res>  {
  factory $WealthSummaryCopyWith(WealthSummary value, $Res Function(WealthSummary) _then) = _$WealthSummaryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'total_wealth') double totalWealth,@JsonKey(name: 'base_currency') String baseCurrency,@JsonKey(name: 'account_count') int accountCount
});




}
/// @nodoc
class _$WealthSummaryCopyWithImpl<$Res>
    implements $WealthSummaryCopyWith<$Res> {
  _$WealthSummaryCopyWithImpl(this._self, this._then);

  final WealthSummary _self;
  final $Res Function(WealthSummary) _then;

/// Create a copy of WealthSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalWealth = null,Object? baseCurrency = null,Object? accountCount = null,}) {
  return _then(_self.copyWith(
totalWealth: null == totalWealth ? _self.totalWealth : totalWealth // ignore: cast_nullable_to_non_nullable
as double,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,accountCount: null == accountCount ? _self.accountCount : accountCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WealthSummary].
extension WealthSummaryPatterns on WealthSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WealthSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WealthSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WealthSummary value)  $default,){
final _that = this;
switch (_that) {
case _WealthSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WealthSummary value)?  $default,){
final _that = this;
switch (_that) {
case _WealthSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'total_wealth')  double totalWealth, @JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'account_count')  int accountCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WealthSummary() when $default != null:
return $default(_that.totalWealth,_that.baseCurrency,_that.accountCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'total_wealth')  double totalWealth, @JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'account_count')  int accountCount)  $default,) {final _that = this;
switch (_that) {
case _WealthSummary():
return $default(_that.totalWealth,_that.baseCurrency,_that.accountCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'total_wealth')  double totalWealth, @JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'account_count')  int accountCount)?  $default,) {final _that = this;
switch (_that) {
case _WealthSummary() when $default != null:
return $default(_that.totalWealth,_that.baseCurrency,_that.accountCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WealthSummary implements WealthSummary {
  const _WealthSummary({@JsonKey(name: 'total_wealth') required this.totalWealth, @JsonKey(name: 'base_currency') required this.baseCurrency, @JsonKey(name: 'account_count') required this.accountCount});
  factory _WealthSummary.fromJson(Map<String, dynamic> json) => _$WealthSummaryFromJson(json);

@override@JsonKey(name: 'total_wealth') final  double totalWealth;
@override@JsonKey(name: 'base_currency') final  String baseCurrency;
@override@JsonKey(name: 'account_count') final  int accountCount;

/// Create a copy of WealthSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WealthSummaryCopyWith<_WealthSummary> get copyWith => __$WealthSummaryCopyWithImpl<_WealthSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WealthSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WealthSummary&&(identical(other.totalWealth, totalWealth) || other.totalWealth == totalWealth)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.accountCount, accountCount) || other.accountCount == accountCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalWealth,baseCurrency,accountCount);

@override
String toString() {
  return 'WealthSummary(totalWealth: $totalWealth, baseCurrency: $baseCurrency, accountCount: $accountCount)';
}


}

/// @nodoc
abstract mixin class _$WealthSummaryCopyWith<$Res> implements $WealthSummaryCopyWith<$Res> {
  factory _$WealthSummaryCopyWith(_WealthSummary value, $Res Function(_WealthSummary) _then) = __$WealthSummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'total_wealth') double totalWealth,@JsonKey(name: 'base_currency') String baseCurrency,@JsonKey(name: 'account_count') int accountCount
});




}
/// @nodoc
class __$WealthSummaryCopyWithImpl<$Res>
    implements _$WealthSummaryCopyWith<$Res> {
  __$WealthSummaryCopyWithImpl(this._self, this._then);

  final _WealthSummary _self;
  final $Res Function(_WealthSummary) _then;

/// Create a copy of WealthSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalWealth = null,Object? baseCurrency = null,Object? accountCount = null,}) {
  return _then(_WealthSummary(
totalWealth: null == totalWealth ? _self.totalWealth : totalWealth // ignore: cast_nullable_to_non_nullable
as double,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,accountCount: null == accountCount ? _self.accountCount : accountCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$WealthHistoryPoint {

 String get date;@JsonKey(name: 'total_wealth') double get totalWealth;
/// Create a copy of WealthHistoryPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WealthHistoryPointCopyWith<WealthHistoryPoint> get copyWith => _$WealthHistoryPointCopyWithImpl<WealthHistoryPoint>(this as WealthHistoryPoint, _$identity);

  /// Serializes this WealthHistoryPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WealthHistoryPoint&&(identical(other.date, date) || other.date == date)&&(identical(other.totalWealth, totalWealth) || other.totalWealth == totalWealth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,totalWealth);

@override
String toString() {
  return 'WealthHistoryPoint(date: $date, totalWealth: $totalWealth)';
}


}

/// @nodoc
abstract mixin class $WealthHistoryPointCopyWith<$Res>  {
  factory $WealthHistoryPointCopyWith(WealthHistoryPoint value, $Res Function(WealthHistoryPoint) _then) = _$WealthHistoryPointCopyWithImpl;
@useResult
$Res call({
 String date,@JsonKey(name: 'total_wealth') double totalWealth
});




}
/// @nodoc
class _$WealthHistoryPointCopyWithImpl<$Res>
    implements $WealthHistoryPointCopyWith<$Res> {
  _$WealthHistoryPointCopyWithImpl(this._self, this._then);

  final WealthHistoryPoint _self;
  final $Res Function(WealthHistoryPoint) _then;

/// Create a copy of WealthHistoryPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? totalWealth = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,totalWealth: null == totalWealth ? _self.totalWealth : totalWealth // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [WealthHistoryPoint].
extension WealthHistoryPointPatterns on WealthHistoryPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WealthHistoryPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WealthHistoryPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WealthHistoryPoint value)  $default,){
final _that = this;
switch (_that) {
case _WealthHistoryPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WealthHistoryPoint value)?  $default,){
final _that = this;
switch (_that) {
case _WealthHistoryPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date, @JsonKey(name: 'total_wealth')  double totalWealth)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WealthHistoryPoint() when $default != null:
return $default(_that.date,_that.totalWealth);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date, @JsonKey(name: 'total_wealth')  double totalWealth)  $default,) {final _that = this;
switch (_that) {
case _WealthHistoryPoint():
return $default(_that.date,_that.totalWealth);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date, @JsonKey(name: 'total_wealth')  double totalWealth)?  $default,) {final _that = this;
switch (_that) {
case _WealthHistoryPoint() when $default != null:
return $default(_that.date,_that.totalWealth);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WealthHistoryPoint implements WealthHistoryPoint {
  const _WealthHistoryPoint({required this.date, @JsonKey(name: 'total_wealth') required this.totalWealth});
  factory _WealthHistoryPoint.fromJson(Map<String, dynamic> json) => _$WealthHistoryPointFromJson(json);

@override final  String date;
@override@JsonKey(name: 'total_wealth') final  double totalWealth;

/// Create a copy of WealthHistoryPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WealthHistoryPointCopyWith<_WealthHistoryPoint> get copyWith => __$WealthHistoryPointCopyWithImpl<_WealthHistoryPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WealthHistoryPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WealthHistoryPoint&&(identical(other.date, date) || other.date == date)&&(identical(other.totalWealth, totalWealth) || other.totalWealth == totalWealth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,totalWealth);

@override
String toString() {
  return 'WealthHistoryPoint(date: $date, totalWealth: $totalWealth)';
}


}

/// @nodoc
abstract mixin class _$WealthHistoryPointCopyWith<$Res> implements $WealthHistoryPointCopyWith<$Res> {
  factory _$WealthHistoryPointCopyWith(_WealthHistoryPoint value, $Res Function(_WealthHistoryPoint) _then) = __$WealthHistoryPointCopyWithImpl;
@override @useResult
$Res call({
 String date,@JsonKey(name: 'total_wealth') double totalWealth
});




}
/// @nodoc
class __$WealthHistoryPointCopyWithImpl<$Res>
    implements _$WealthHistoryPointCopyWith<$Res> {
  __$WealthHistoryPointCopyWithImpl(this._self, this._then);

  final _WealthHistoryPoint _self;
  final $Res Function(_WealthHistoryPoint) _then;

/// Create a copy of WealthHistoryPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? totalWealth = null,}) {
  return _then(_WealthHistoryPoint(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,totalWealth: null == totalWealth ? _self.totalWealth : totalWealth // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
