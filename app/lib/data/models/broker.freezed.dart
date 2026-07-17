// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broker.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Broker {

 String get code; String get name;@JsonKey(name: 'supports_auto_sync') bool get supportsAutoSync;
/// Create a copy of Broker
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BrokerCopyWith<Broker> get copyWith => _$BrokerCopyWithImpl<Broker>(this as Broker, _$identity);

  /// Serializes this Broker to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Broker&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.supportsAutoSync, supportsAutoSync) || other.supportsAutoSync == supportsAutoSync));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,name,supportsAutoSync);

@override
String toString() {
  return 'Broker(code: $code, name: $name, supportsAutoSync: $supportsAutoSync)';
}


}

/// @nodoc
abstract mixin class $BrokerCopyWith<$Res>  {
  factory $BrokerCopyWith(Broker value, $Res Function(Broker) _then) = _$BrokerCopyWithImpl;
@useResult
$Res call({
 String code, String name,@JsonKey(name: 'supports_auto_sync') bool supportsAutoSync
});




}
/// @nodoc
class _$BrokerCopyWithImpl<$Res>
    implements $BrokerCopyWith<$Res> {
  _$BrokerCopyWithImpl(this._self, this._then);

  final Broker _self;
  final $Res Function(Broker) _then;

/// Create a copy of Broker
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? supportsAutoSync = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,supportsAutoSync: null == supportsAutoSync ? _self.supportsAutoSync : supportsAutoSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Broker].
extension BrokerPatterns on Broker {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Broker value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Broker() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Broker value)  $default,){
final _that = this;
switch (_that) {
case _Broker():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Broker value)?  $default,){
final _that = this;
switch (_that) {
case _Broker() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name, @JsonKey(name: 'supports_auto_sync')  bool supportsAutoSync)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Broker() when $default != null:
return $default(_that.code,_that.name,_that.supportsAutoSync);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name, @JsonKey(name: 'supports_auto_sync')  bool supportsAutoSync)  $default,) {final _that = this;
switch (_that) {
case _Broker():
return $default(_that.code,_that.name,_that.supportsAutoSync);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name, @JsonKey(name: 'supports_auto_sync')  bool supportsAutoSync)?  $default,) {final _that = this;
switch (_that) {
case _Broker() when $default != null:
return $default(_that.code,_that.name,_that.supportsAutoSync);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Broker implements Broker {
  const _Broker({required this.code, required this.name, @JsonKey(name: 'supports_auto_sync') this.supportsAutoSync = false});
  factory _Broker.fromJson(Map<String, dynamic> json) => _$BrokerFromJson(json);

@override final  String code;
@override final  String name;
@override@JsonKey(name: 'supports_auto_sync') final  bool supportsAutoSync;

/// Create a copy of Broker
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BrokerCopyWith<_Broker> get copyWith => __$BrokerCopyWithImpl<_Broker>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BrokerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Broker&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.supportsAutoSync, supportsAutoSync) || other.supportsAutoSync == supportsAutoSync));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,name,supportsAutoSync);

@override
String toString() {
  return 'Broker(code: $code, name: $name, supportsAutoSync: $supportsAutoSync)';
}


}

/// @nodoc
abstract mixin class _$BrokerCopyWith<$Res> implements $BrokerCopyWith<$Res> {
  factory _$BrokerCopyWith(_Broker value, $Res Function(_Broker) _then) = __$BrokerCopyWithImpl;
@override @useResult
$Res call({
 String code, String name,@JsonKey(name: 'supports_auto_sync') bool supportsAutoSync
});




}
/// @nodoc
class __$BrokerCopyWithImpl<$Res>
    implements _$BrokerCopyWith<$Res> {
  __$BrokerCopyWithImpl(this._self, this._then);

  final _Broker _self;
  final $Res Function(_Broker) _then;

/// Create a copy of Broker
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? supportsAutoSync = null,}) {
  return _then(_Broker(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,supportsAutoSync: null == supportsAutoSync ? _self.supportsAutoSync : supportsAutoSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
