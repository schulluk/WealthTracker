// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'simulation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SimulationBand {

 int get year; double get p5; double get p25; double get p50; double get p75; double get p95;
/// Create a copy of SimulationBand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SimulationBandCopyWith<SimulationBand> get copyWith => _$SimulationBandCopyWithImpl<SimulationBand>(this as SimulationBand, _$identity);

  /// Serializes this SimulationBand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SimulationBand;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SimulationBand&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.p5, _this.p5) || other.p5 == _this.p5)&&(identical(other.p25, _this.p25) || other.p25 == _this.p25)&&(identical(other.p50, _this.p50) || other.p50 == _this.p50)&&(identical(other.p75, _this.p75) || other.p75 == _this.p75)&&(identical(other.p95, _this.p95) || other.p95 == _this.p95));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SimulationBand;
  return Object.hash(runtimeType,_this.year,_this.p5,_this.p25,_this.p50,_this.p75,_this.p95);
}

@override
String toString() {
  final _this = this as SimulationBand;
  return 'SimulationBand(year: ${_this.year}, p5: ${_this.p5}, p25: ${_this.p25}, p50: ${_this.p50}, p75: ${_this.p75}, p95: ${_this.p95})';
}


}

/// @nodoc
abstract mixin class $SimulationBandCopyWith<$Res>  {
  factory $SimulationBandCopyWith(SimulationBand value, $Res Function(SimulationBand) _then) = _$SimulationBandCopyWithImpl;
@useResult
$Res call({
 int year, double p5, double p25, double p50, double p75, double p95
});




}
/// @nodoc
class _$SimulationBandCopyWithImpl<$Res>
    implements $SimulationBandCopyWith<$Res> {
  _$SimulationBandCopyWithImpl(this._self, this._then);

  final SimulationBand _self;
  final $Res Function(SimulationBand) _then;

/// Create a copy of SimulationBand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? year = null,Object? p5 = null,Object? p25 = null,Object? p50 = null,Object? p75 = null,Object? p95 = null,}) {
  return _then(SimulationBand(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,p5: null == p5 ? _self.p5 : p5 // ignore: cast_nullable_to_non_nullable
as double,p25: null == p25 ? _self.p25 : p25 // ignore: cast_nullable_to_non_nullable
as double,p50: null == p50 ? _self.p50 : p50 // ignore: cast_nullable_to_non_nullable
as double,p75: null == p75 ? _self.p75 : p75 // ignore: cast_nullable_to_non_nullable
as double,p95: null == p95 ? _self.p95 : p95 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SimulationBand].
extension SimulationBandPatterns on SimulationBand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SimulationBand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SimulationBand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SimulationBand value)  $default,){
final _that = this;
switch (_that) {
case _SimulationBand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SimulationBand value)?  $default,){
final _that = this;
switch (_that) {
case _SimulationBand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int year,  double p5,  double p25,  double p50,  double p75,  double p95)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SimulationBand() when $default != null:
return $default(_that.year,_that.p5,_that.p25,_that.p50,_that.p75,_that.p95);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int year,  double p5,  double p25,  double p50,  double p75,  double p95)  $default,) {final _that = this;
switch (_that) {
case _SimulationBand():
return $default(_that.year,_that.p5,_that.p25,_that.p50,_that.p75,_that.p95);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int year,  double p5,  double p25,  double p50,  double p75,  double p95)?  $default,) {final _that = this;
switch (_that) {
case _SimulationBand() when $default != null:
return $default(_that.year,_that.p5,_that.p25,_that.p50,_that.p75,_that.p95);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SimulationBand implements SimulationBand {
  const _SimulationBand({required this.year, required this.p5, required this.p25, required this.p50, required this.p75, required this.p95});
  factory _SimulationBand.fromJson(Map<String, dynamic> json) => _$SimulationBandFromJson(json);

@override final  int year;
@override final  double p5;
@override final  double p25;
@override final  double p50;
@override final  double p75;
@override final  double p95;

/// Create a copy of SimulationBand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SimulationBandCopyWith<_SimulationBand> get copyWith => __$SimulationBandCopyWithImpl<_SimulationBand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SimulationBandToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SimulationBand&&(identical(other.year, year) || other.year == year)&&(identical(other.p5, p5) || other.p5 == p5)&&(identical(other.p25, p25) || other.p25 == p25)&&(identical(other.p50, p50) || other.p50 == p50)&&(identical(other.p75, p75) || other.p75 == p75)&&(identical(other.p95, p95) || other.p95 == p95));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,year,p5,p25,p50,p75,p95);
}

@override
String toString() {
    return 'SimulationBand(year: $year, p5: $p5, p25: $p25, p50: $p50, p75: $p75, p95: $p95)';
}


}

/// @nodoc
abstract mixin class _$SimulationBandCopyWith<$Res> implements $SimulationBandCopyWith<$Res> {
  factory _$SimulationBandCopyWith(_SimulationBand value, $Res Function(_SimulationBand) _then) = __$SimulationBandCopyWithImpl;
@override @useResult
$Res call({
 int year, double p5, double p25, double p50, double p75, double p95
});




}
/// @nodoc
class __$SimulationBandCopyWithImpl<$Res>
    implements _$SimulationBandCopyWith<$Res> {
  __$SimulationBandCopyWithImpl(this._self, this._then);

  final _SimulationBand _self;
  final $Res Function(_SimulationBand) _then;

/// Create a copy of SimulationBand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? year = null,Object? p5 = null,Object? p25 = null,Object? p50 = null,Object? p75 = null,Object? p95 = null,}) {
  return _then(_SimulationBand(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,p5: null == p5 ? _self.p5 : p5 // ignore: cast_nullable_to_non_nullable
as double,p25: null == p25 ? _self.p25 : p25 // ignore: cast_nullable_to_non_nullable
as double,p50: null == p50 ? _self.p50 : p50 // ignore: cast_nullable_to_non_nullable
as double,p75: null == p75 ? _self.p75 : p75 // ignore: cast_nullable_to_non_nullable
as double,p95: null == p95 ? _self.p95 : p95 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$SimulationParameter {

 double get value; bool get derived;
/// Create a copy of SimulationParameter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SimulationParameterCopyWith<SimulationParameter> get copyWith => _$SimulationParameterCopyWithImpl<SimulationParameter>(this as SimulationParameter, _$identity);

  /// Serializes this SimulationParameter to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SimulationParameter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SimulationParameter&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.derived, _this.derived) || other.derived == _this.derived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SimulationParameter;
  return Object.hash(runtimeType,_this.value,_this.derived);
}

@override
String toString() {
  final _this = this as SimulationParameter;
  return 'SimulationParameter(value: ${_this.value}, derived: ${_this.derived})';
}


}

/// @nodoc
abstract mixin class $SimulationParameterCopyWith<$Res>  {
  factory $SimulationParameterCopyWith(SimulationParameter value, $Res Function(SimulationParameter) _then) = _$SimulationParameterCopyWithImpl;
@useResult
$Res call({
 double value, bool derived
});




}
/// @nodoc
class _$SimulationParameterCopyWithImpl<$Res>
    implements $SimulationParameterCopyWith<$Res> {
  _$SimulationParameterCopyWithImpl(this._self, this._then);

  final SimulationParameter _self;
  final $Res Function(SimulationParameter) _then;

/// Create a copy of SimulationParameter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? derived = null,}) {
  return _then(SimulationParameter(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,derived: null == derived ? _self.derived : derived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SimulationParameter].
extension SimulationParameterPatterns on SimulationParameter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SimulationParameter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SimulationParameter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SimulationParameter value)  $default,){
final _that = this;
switch (_that) {
case _SimulationParameter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SimulationParameter value)?  $default,){
final _that = this;
switch (_that) {
case _SimulationParameter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double value,  bool derived)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SimulationParameter() when $default != null:
return $default(_that.value,_that.derived);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double value,  bool derived)  $default,) {final _that = this;
switch (_that) {
case _SimulationParameter():
return $default(_that.value,_that.derived);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double value,  bool derived)?  $default,) {final _that = this;
switch (_that) {
case _SimulationParameter() when $default != null:
return $default(_that.value,_that.derived);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SimulationParameter implements SimulationParameter {
  const _SimulationParameter({required this.value, required this.derived});
  factory _SimulationParameter.fromJson(Map<String, dynamic> json) => _$SimulationParameterFromJson(json);

@override final  double value;
@override final  bool derived;

/// Create a copy of SimulationParameter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SimulationParameterCopyWith<_SimulationParameter> get copyWith => __$SimulationParameterCopyWithImpl<_SimulationParameter>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SimulationParameterToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SimulationParameter&&(identical(other.value, value) || other.value == value)&&(identical(other.derived, derived) || other.derived == derived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value,derived);
}

@override
String toString() {
    return 'SimulationParameter(value: $value, derived: $derived)';
}


}

/// @nodoc
abstract mixin class _$SimulationParameterCopyWith<$Res> implements $SimulationParameterCopyWith<$Res> {
  factory _$SimulationParameterCopyWith(_SimulationParameter value, $Res Function(_SimulationParameter) _then) = __$SimulationParameterCopyWithImpl;
@override @useResult
$Res call({
 double value, bool derived
});




}
/// @nodoc
class __$SimulationParameterCopyWithImpl<$Res>
    implements _$SimulationParameterCopyWith<$Res> {
  __$SimulationParameterCopyWithImpl(this._self, this._then);

  final _SimulationParameter _self;
  final $Res Function(_SimulationParameter) _then;

/// Create a copy of SimulationParameter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? derived = null,}) {
  return _then(_SimulationParameter(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,derived: null == derived ? _self.derived : derived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SimulationTarget {

 double get amount; double get probability;/// Probability of being at/above the target at each year end (index =
/// year). Lets the client re-slice the horizon without a new request.
@JsonKey(name: 'probability_by_year') List<double> get probabilityByYear;@JsonKey(name: 'median_reached_year') int? get medianReachedYear;
/// Create a copy of SimulationTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SimulationTargetCopyWith<SimulationTarget> get copyWith => _$SimulationTargetCopyWithImpl<SimulationTarget>(this as SimulationTarget, _$identity);

  /// Serializes this SimulationTarget to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SimulationTarget;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SimulationTarget&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.probability, _this.probability) || other.probability == _this.probability)&&const DeepCollectionEquality().equals(other.probabilityByYear, _this.probabilityByYear)&&(identical(other.medianReachedYear, _this.medianReachedYear) || other.medianReachedYear == _this.medianReachedYear));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SimulationTarget;
  return Object.hash(runtimeType,_this.amount,_this.probability,const DeepCollectionEquality().hash(_this.probabilityByYear),_this.medianReachedYear);
}

@override
String toString() {
  final _this = this as SimulationTarget;
  return 'SimulationTarget(amount: ${_this.amount}, probability: ${_this.probability}, probabilityByYear: ${_this.probabilityByYear}, medianReachedYear: ${_this.medianReachedYear})';
}


}

/// @nodoc
abstract mixin class $SimulationTargetCopyWith<$Res>  {
  factory $SimulationTargetCopyWith(SimulationTarget value, $Res Function(SimulationTarget) _then) = _$SimulationTargetCopyWithImpl;
@useResult
$Res call({
 double amount, double probability,@JsonKey(name: 'probability_by_year') List<double> probabilityByYear,@JsonKey(name: 'median_reached_year') int? medianReachedYear
});




}
/// @nodoc
class _$SimulationTargetCopyWithImpl<$Res>
    implements $SimulationTargetCopyWith<$Res> {
  _$SimulationTargetCopyWithImpl(this._self, this._then);

  final SimulationTarget _self;
  final $Res Function(SimulationTarget) _then;

/// Create a copy of SimulationTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? amount = null,Object? probability = null,Object? probabilityByYear = null,Object? medianReachedYear = freezed,}) {
  return _then(SimulationTarget(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,probability: null == probability ? _self.probability : probability // ignore: cast_nullable_to_non_nullable
as double,probabilityByYear: null == probabilityByYear ? _self.probabilityByYear : probabilityByYear // ignore: cast_nullable_to_non_nullable
as List<double>,medianReachedYear: freezed == medianReachedYear ? _self.medianReachedYear : medianReachedYear // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SimulationTarget].
extension SimulationTargetPatterns on SimulationTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SimulationTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SimulationTarget() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SimulationTarget value)  $default,){
final _that = this;
switch (_that) {
case _SimulationTarget():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SimulationTarget value)?  $default,){
final _that = this;
switch (_that) {
case _SimulationTarget() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double amount,  double probability, @JsonKey(name: 'probability_by_year')  List<double> probabilityByYear, @JsonKey(name: 'median_reached_year')  int? medianReachedYear)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SimulationTarget() when $default != null:
return $default(_that.amount,_that.probability,_that.probabilityByYear,_that.medianReachedYear);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double amount,  double probability, @JsonKey(name: 'probability_by_year')  List<double> probabilityByYear, @JsonKey(name: 'median_reached_year')  int? medianReachedYear)  $default,) {final _that = this;
switch (_that) {
case _SimulationTarget():
return $default(_that.amount,_that.probability,_that.probabilityByYear,_that.medianReachedYear);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double amount,  double probability, @JsonKey(name: 'probability_by_year')  List<double> probabilityByYear, @JsonKey(name: 'median_reached_year')  int? medianReachedYear)?  $default,) {final _that = this;
switch (_that) {
case _SimulationTarget() when $default != null:
return $default(_that.amount,_that.probability,_that.probabilityByYear,_that.medianReachedYear);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SimulationTarget implements SimulationTarget {
  const _SimulationTarget({required this.amount, required this.probability, @JsonKey(name: 'probability_by_year')  List<double> probabilityByYear = const <double>[], @JsonKey(name: 'median_reached_year') this.medianReachedYear}): _probabilityByYear = probabilityByYear;
  factory _SimulationTarget.fromJson(Map<String, dynamic> json) => _$SimulationTargetFromJson(json);

@override final  double amount;
@override final  double probability;
/// Probability of being at/above the target at each year end (index =
/// year). Lets the client re-slice the horizon without a new request.
 final  List<double> _probabilityByYear;
/// Probability of being at/above the target at each year end (index =
/// year). Lets the client re-slice the horizon without a new request.
@override@JsonKey(name: 'probability_by_year') List<double> get probabilityByYear {
  if (_probabilityByYear is EqualUnmodifiableListView) return _probabilityByYear;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_probabilityByYear);
}

@override@JsonKey(name: 'median_reached_year') final  int? medianReachedYear;

/// Create a copy of SimulationTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SimulationTargetCopyWith<_SimulationTarget> get copyWith => __$SimulationTargetCopyWithImpl<_SimulationTarget>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SimulationTargetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SimulationTarget&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.probability, probability) || other.probability == probability)&&const DeepCollectionEquality().equals(other.probabilityByYear, _probabilityByYear)&&(identical(other.medianReachedYear, medianReachedYear) || other.medianReachedYear == medianReachedYear));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,amount,probability,const DeepCollectionEquality().hash(_probabilityByYear),medianReachedYear);
}

@override
String toString() {
    return 'SimulationTarget(amount: $amount, probability: $probability, probabilityByYear: $probabilityByYear, medianReachedYear: $medianReachedYear)';
}


}

/// @nodoc
abstract mixin class _$SimulationTargetCopyWith<$Res> implements $SimulationTargetCopyWith<$Res> {
  factory _$SimulationTargetCopyWith(_SimulationTarget value, $Res Function(_SimulationTarget) _then) = __$SimulationTargetCopyWithImpl;
@override @useResult
$Res call({
 double amount, double probability,@JsonKey(name: 'probability_by_year') List<double> probabilityByYear,@JsonKey(name: 'median_reached_year') int? medianReachedYear
});




}
/// @nodoc
class __$SimulationTargetCopyWithImpl<$Res>
    implements _$SimulationTargetCopyWith<$Res> {
  __$SimulationTargetCopyWithImpl(this._self, this._then);

  final _SimulationTarget _self;
  final $Res Function(_SimulationTarget) _then;

/// Create a copy of SimulationTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? amount = null,Object? probability = null,Object? probabilityByYear = null,Object? medianReachedYear = freezed,}) {
  return _then(_SimulationTarget(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,probability: null == probability ? _self.probability : probability // ignore: cast_nullable_to_non_nullable
as double,probabilityByYear: null == probabilityByYear ? _self._probabilityByYear : probabilityByYear // ignore: cast_nullable_to_non_nullable
as List<double>,medianReachedYear: freezed == medianReachedYear ? _self.medianReachedYear : medianReachedYear // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$SimulationResult {

 int get years; int get paths;@JsonKey(name: 'base_currency') String get baseCurrency; List<SimulationBand> get bands; Map<String, SimulationParameter> get parameters; SimulationTarget? get target;
/// Create a copy of SimulationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SimulationResultCopyWith<SimulationResult> get copyWith => _$SimulationResultCopyWithImpl<SimulationResult>(this as SimulationResult, _$identity);

  /// Serializes this SimulationResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SimulationResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SimulationResult&&(identical(other.years, _this.years) || other.years == _this.years)&&(identical(other.paths, _this.paths) || other.paths == _this.paths)&&(identical(other.baseCurrency, _this.baseCurrency) || other.baseCurrency == _this.baseCurrency)&&const DeepCollectionEquality().equals(other.bands, _this.bands)&&const DeepCollectionEquality().equals(other.parameters, _this.parameters)&&(identical(other.target, _this.target) || other.target == _this.target));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SimulationResult;
  return Object.hash(runtimeType,_this.years,_this.paths,_this.baseCurrency,const DeepCollectionEquality().hash(_this.bands),const DeepCollectionEquality().hash(_this.parameters),_this.target);
}

@override
String toString() {
  final _this = this as SimulationResult;
  return 'SimulationResult(years: ${_this.years}, paths: ${_this.paths}, baseCurrency: ${_this.baseCurrency}, bands: ${_this.bands}, parameters: ${_this.parameters}, target: ${_this.target})';
}


}

/// @nodoc
abstract mixin class $SimulationResultCopyWith<$Res>  {
  factory $SimulationResultCopyWith(SimulationResult value, $Res Function(SimulationResult) _then) = _$SimulationResultCopyWithImpl;
@useResult
$Res call({
 int years, int paths,@JsonKey(name: 'base_currency') String baseCurrency, List<SimulationBand> bands, Map<String, SimulationParameter> parameters, SimulationTarget? target
});


$SimulationTargetCopyWith<$Res>? get target;

}
/// @nodoc
class _$SimulationResultCopyWithImpl<$Res>
    implements $SimulationResultCopyWith<$Res> {
  _$SimulationResultCopyWithImpl(this._self, this._then);

  final SimulationResult _self;
  final $Res Function(SimulationResult) _then;

/// Create a copy of SimulationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? years = null,Object? paths = null,Object? baseCurrency = null,Object? bands = null,Object? parameters = null,Object? target = freezed,}) {
  return _then(SimulationResult(
years: null == years ? _self.years : years // ignore: cast_nullable_to_non_nullable
as int,paths: null == paths ? _self.paths : paths // ignore: cast_nullable_to_non_nullable
as int,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,bands: null == bands ? _self.bands : bands // ignore: cast_nullable_to_non_nullable
as List<SimulationBand>,parameters: null == parameters ? _self.parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, SimulationParameter>,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as SimulationTarget?,
  ));
}
/// Create a copy of SimulationResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SimulationTargetCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $SimulationTargetCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// Adds pattern-matching-related methods to [SimulationResult].
extension SimulationResultPatterns on SimulationResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SimulationResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SimulationResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SimulationResult value)  $default,){
final _that = this;
switch (_that) {
case _SimulationResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SimulationResult value)?  $default,){
final _that = this;
switch (_that) {
case _SimulationResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int years,  int paths, @JsonKey(name: 'base_currency')  String baseCurrency,  List<SimulationBand> bands,  Map<String, SimulationParameter> parameters,  SimulationTarget? target)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SimulationResult() when $default != null:
return $default(_that.years,_that.paths,_that.baseCurrency,_that.bands,_that.parameters,_that.target);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int years,  int paths, @JsonKey(name: 'base_currency')  String baseCurrency,  List<SimulationBand> bands,  Map<String, SimulationParameter> parameters,  SimulationTarget? target)  $default,) {final _that = this;
switch (_that) {
case _SimulationResult():
return $default(_that.years,_that.paths,_that.baseCurrency,_that.bands,_that.parameters,_that.target);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int years,  int paths, @JsonKey(name: 'base_currency')  String baseCurrency,  List<SimulationBand> bands,  Map<String, SimulationParameter> parameters,  SimulationTarget? target)?  $default,) {final _that = this;
switch (_that) {
case _SimulationResult() when $default != null:
return $default(_that.years,_that.paths,_that.baseCurrency,_that.bands,_that.parameters,_that.target);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SimulationResult implements SimulationResult {
  const _SimulationResult({required this.years, required this.paths, @JsonKey(name: 'base_currency') required this.baseCurrency, required  List<SimulationBand> bands, required  Map<String, SimulationParameter> parameters, this.target}): _bands = bands,_parameters = parameters;
  factory _SimulationResult.fromJson(Map<String, dynamic> json) => _$SimulationResultFromJson(json);

@override final  int years;
@override final  int paths;
@override@JsonKey(name: 'base_currency') final  String baseCurrency;
 final  List<SimulationBand> _bands;
@override List<SimulationBand> get bands {
  if (_bands is EqualUnmodifiableListView) return _bands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bands);
}

 final  Map<String, SimulationParameter> _parameters;
@override Map<String, SimulationParameter> get parameters {
  if (_parameters is EqualUnmodifiableMapView) return _parameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_parameters);
}

@override final  SimulationTarget? target;

/// Create a copy of SimulationResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SimulationResultCopyWith<_SimulationResult> get copyWith => __$SimulationResultCopyWithImpl<_SimulationResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SimulationResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SimulationResult&&(identical(other.years, years) || other.years == years)&&(identical(other.paths, paths) || other.paths == paths)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&const DeepCollectionEquality().equals(other.bands, _bands)&&const DeepCollectionEquality().equals(other.parameters, _parameters)&&(identical(other.target, target) || other.target == target));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,years,paths,baseCurrency,const DeepCollectionEquality().hash(_bands),const DeepCollectionEquality().hash(_parameters),target);
}

@override
String toString() {
    return 'SimulationResult(years: $years, paths: $paths, baseCurrency: $baseCurrency, bands: $bands, parameters: $parameters, target: $target)';
}


}

/// @nodoc
abstract mixin class _$SimulationResultCopyWith<$Res> implements $SimulationResultCopyWith<$Res> {
  factory _$SimulationResultCopyWith(_SimulationResult value, $Res Function(_SimulationResult) _then) = __$SimulationResultCopyWithImpl;
@override @useResult
$Res call({
 int years, int paths,@JsonKey(name: 'base_currency') String baseCurrency, List<SimulationBand> bands, Map<String, SimulationParameter> parameters, SimulationTarget? target
});


@override $SimulationTargetCopyWith<$Res>? get target;

}
/// @nodoc
class __$SimulationResultCopyWithImpl<$Res>
    implements _$SimulationResultCopyWith<$Res> {
  __$SimulationResultCopyWithImpl(this._self, this._then);

  final _SimulationResult _self;
  final $Res Function(_SimulationResult) _then;

/// Create a copy of SimulationResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? years = null,Object? paths = null,Object? baseCurrency = null,Object? bands = null,Object? parameters = null,Object? target = freezed,}) {
  return _then(_SimulationResult(
years: null == years ? _self.years : years // ignore: cast_nullable_to_non_nullable
as int,paths: null == paths ? _self.paths : paths // ignore: cast_nullable_to_non_nullable
as int,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,bands: null == bands ? _self._bands : bands // ignore: cast_nullable_to_non_nullable
as List<SimulationBand>,parameters: null == parameters ? _self._parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, SimulationParameter>,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as SimulationTarget?,
  ));
}

/// Create a copy of SimulationResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SimulationTargetCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $SimulationTargetCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

// dart format on
