// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_categorization.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiPricing {

 String get model;@JsonKey(name: 'display_name') String get displayName;@JsonKey(name: 'input_price_per_1m') double? get inputPricePer1m;@JsonKey(name: 'output_price_per_1m') double? get outputPricePer1m;@JsonKey(name: 'checked_at') String get checkedAt;@JsonKey(name: 'table_updated') String? get tableUpdated;
/// Create a copy of AiPricing
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiPricingCopyWith<AiPricing> get copyWith => _$AiPricingCopyWithImpl<AiPricing>(this as AiPricing, _$identity);

  /// Serializes this AiPricing to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiPricing;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiPricing&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.inputPricePer1m, _this.inputPricePer1m) || other.inputPricePer1m == _this.inputPricePer1m)&&(identical(other.outputPricePer1m, _this.outputPricePer1m) || other.outputPricePer1m == _this.outputPricePer1m)&&(identical(other.checkedAt, _this.checkedAt) || other.checkedAt == _this.checkedAt)&&(identical(other.tableUpdated, _this.tableUpdated) || other.tableUpdated == _this.tableUpdated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiPricing;
  return Object.hash(runtimeType,_this.model,_this.displayName,_this.inputPricePer1m,_this.outputPricePer1m,_this.checkedAt,_this.tableUpdated);
}

@override
String toString() {
  final _this = this as AiPricing;
  return 'AiPricing(model: ${_this.model}, displayName: ${_this.displayName}, inputPricePer1m: ${_this.inputPricePer1m}, outputPricePer1m: ${_this.outputPricePer1m}, checkedAt: ${_this.checkedAt}, tableUpdated: ${_this.tableUpdated})';
}


}

/// @nodoc
abstract mixin class $AiPricingCopyWith<$Res>  {
  factory $AiPricingCopyWith(AiPricing value, $Res Function(AiPricing) _then) = _$AiPricingCopyWithImpl;
@useResult
$Res call({
 String model,@JsonKey(name: 'display_name') String displayName,@JsonKey(name: 'input_price_per_1m') double? inputPricePer1m,@JsonKey(name: 'output_price_per_1m') double? outputPricePer1m,@JsonKey(name: 'checked_at') String checkedAt,@JsonKey(name: 'table_updated') String? tableUpdated
});




}
/// @nodoc
class _$AiPricingCopyWithImpl<$Res>
    implements $AiPricingCopyWith<$Res> {
  _$AiPricingCopyWithImpl(this._self, this._then);

  final AiPricing _self;
  final $Res Function(AiPricing) _then;

/// Create a copy of AiPricing
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,Object? displayName = null,Object? inputPricePer1m = freezed,Object? outputPricePer1m = freezed,Object? checkedAt = null,Object? tableUpdated = freezed,}) {
  return _then(AiPricing(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,inputPricePer1m: freezed == inputPricePer1m ? _self.inputPricePer1m : inputPricePer1m // ignore: cast_nullable_to_non_nullable
as double?,outputPricePer1m: freezed == outputPricePer1m ? _self.outputPricePer1m : outputPricePer1m // ignore: cast_nullable_to_non_nullable
as double?,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as String,tableUpdated: freezed == tableUpdated ? _self.tableUpdated : tableUpdated // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiPricing].
extension AiPricingPatterns on AiPricing {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiPricing value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiPricing() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiPricing value)  $default,){
final _that = this;
switch (_that) {
case _AiPricing():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiPricing value)?  $default,){
final _that = this;
switch (_that) {
case _AiPricing() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String model, @JsonKey(name: 'display_name')  String displayName, @JsonKey(name: 'input_price_per_1m')  double? inputPricePer1m, @JsonKey(name: 'output_price_per_1m')  double? outputPricePer1m, @JsonKey(name: 'checked_at')  String checkedAt, @JsonKey(name: 'table_updated')  String? tableUpdated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiPricing() when $default != null:
return $default(_that.model,_that.displayName,_that.inputPricePer1m,_that.outputPricePer1m,_that.checkedAt,_that.tableUpdated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String model, @JsonKey(name: 'display_name')  String displayName, @JsonKey(name: 'input_price_per_1m')  double? inputPricePer1m, @JsonKey(name: 'output_price_per_1m')  double? outputPricePer1m, @JsonKey(name: 'checked_at')  String checkedAt, @JsonKey(name: 'table_updated')  String? tableUpdated)  $default,) {final _that = this;
switch (_that) {
case _AiPricing():
return $default(_that.model,_that.displayName,_that.inputPricePer1m,_that.outputPricePer1m,_that.checkedAt,_that.tableUpdated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String model, @JsonKey(name: 'display_name')  String displayName, @JsonKey(name: 'input_price_per_1m')  double? inputPricePer1m, @JsonKey(name: 'output_price_per_1m')  double? outputPricePer1m, @JsonKey(name: 'checked_at')  String checkedAt, @JsonKey(name: 'table_updated')  String? tableUpdated)?  $default,) {final _that = this;
switch (_that) {
case _AiPricing() when $default != null:
return $default(_that.model,_that.displayName,_that.inputPricePer1m,_that.outputPricePer1m,_that.checkedAt,_that.tableUpdated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiPricing implements AiPricing {
  const _AiPricing({required this.model, @JsonKey(name: 'display_name') required this.displayName, @JsonKey(name: 'input_price_per_1m') this.inputPricePer1m, @JsonKey(name: 'output_price_per_1m') this.outputPricePer1m, @JsonKey(name: 'checked_at') required this.checkedAt, @JsonKey(name: 'table_updated') this.tableUpdated});
  factory _AiPricing.fromJson(Map<String, dynamic> json) => _$AiPricingFromJson(json);

@override final  String model;
@override@JsonKey(name: 'display_name') final  String displayName;
@override@JsonKey(name: 'input_price_per_1m') final  double? inputPricePer1m;
@override@JsonKey(name: 'output_price_per_1m') final  double? outputPricePer1m;
@override@JsonKey(name: 'checked_at') final  String checkedAt;
@override@JsonKey(name: 'table_updated') final  String? tableUpdated;

/// Create a copy of AiPricing
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiPricingCopyWith<_AiPricing> get copyWith => __$AiPricingCopyWithImpl<_AiPricing>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiPricingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiPricing&&(identical(other.model, model) || other.model == model)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.inputPricePer1m, inputPricePer1m) || other.inputPricePer1m == inputPricePer1m)&&(identical(other.outputPricePer1m, outputPricePer1m) || other.outputPricePer1m == outputPricePer1m)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt)&&(identical(other.tableUpdated, tableUpdated) || other.tableUpdated == tableUpdated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,model,displayName,inputPricePer1m,outputPricePer1m,checkedAt,tableUpdated);
}

@override
String toString() {
    return 'AiPricing(model: $model, displayName: $displayName, inputPricePer1m: $inputPricePer1m, outputPricePer1m: $outputPricePer1m, checkedAt: $checkedAt, tableUpdated: $tableUpdated)';
}


}

/// @nodoc
abstract mixin class _$AiPricingCopyWith<$Res> implements $AiPricingCopyWith<$Res> {
  factory _$AiPricingCopyWith(_AiPricing value, $Res Function(_AiPricing) _then) = __$AiPricingCopyWithImpl;
@override @useResult
$Res call({
 String model,@JsonKey(name: 'display_name') String displayName,@JsonKey(name: 'input_price_per_1m') double? inputPricePer1m,@JsonKey(name: 'output_price_per_1m') double? outputPricePer1m,@JsonKey(name: 'checked_at') String checkedAt,@JsonKey(name: 'table_updated') String? tableUpdated
});




}
/// @nodoc
class __$AiPricingCopyWithImpl<$Res>
    implements _$AiPricingCopyWith<$Res> {
  __$AiPricingCopyWithImpl(this._self, this._then);

  final _AiPricing _self;
  final $Res Function(_AiPricing) _then;

/// Create a copy of AiPricing
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,Object? displayName = null,Object? inputPricePer1m = freezed,Object? outputPricePer1m = freezed,Object? checkedAt = null,Object? tableUpdated = freezed,}) {
  return _then(_AiPricing(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,inputPricePer1m: freezed == inputPricePer1m ? _self.inputPricePer1m : inputPricePer1m // ignore: cast_nullable_to_non_nullable
as double?,outputPricePer1m: freezed == outputPricePer1m ? _self.outputPricePer1m : outputPricePer1m // ignore: cast_nullable_to_non_nullable
as double?,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as String,tableUpdated: freezed == tableUpdated ? _self.tableUpdated : tableUpdated // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AiConfig {

 bool get configured; String get model; AiPricing? get pricing;@JsonKey(name: 'pricing_source_url') String get pricingSourceUrl;@JsonKey(name: 'disclosed_fields') List<String> get disclosedFields;
/// Create a copy of AiConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiConfigCopyWith<AiConfig> get copyWith => _$AiConfigCopyWithImpl<AiConfig>(this as AiConfig, _$identity);

  /// Serializes this AiConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiConfig&&(identical(other.configured, _this.configured) || other.configured == _this.configured)&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.pricing, _this.pricing) || other.pricing == _this.pricing)&&(identical(other.pricingSourceUrl, _this.pricingSourceUrl) || other.pricingSourceUrl == _this.pricingSourceUrl)&&const DeepCollectionEquality().equals(other.disclosedFields, _this.disclosedFields));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiConfig;
  return Object.hash(runtimeType,_this.configured,_this.model,_this.pricing,_this.pricingSourceUrl,const DeepCollectionEquality().hash(_this.disclosedFields));
}

@override
String toString() {
  final _this = this as AiConfig;
  return 'AiConfig(configured: ${_this.configured}, model: ${_this.model}, pricing: ${_this.pricing}, pricingSourceUrl: ${_this.pricingSourceUrl}, disclosedFields: ${_this.disclosedFields})';
}


}

/// @nodoc
abstract mixin class $AiConfigCopyWith<$Res>  {
  factory $AiConfigCopyWith(AiConfig value, $Res Function(AiConfig) _then) = _$AiConfigCopyWithImpl;
@useResult
$Res call({
 bool configured, String model, AiPricing? pricing,@JsonKey(name: 'pricing_source_url') String pricingSourceUrl,@JsonKey(name: 'disclosed_fields') List<String> disclosedFields
});


$AiPricingCopyWith<$Res>? get pricing;

}
/// @nodoc
class _$AiConfigCopyWithImpl<$Res>
    implements $AiConfigCopyWith<$Res> {
  _$AiConfigCopyWithImpl(this._self, this._then);

  final AiConfig _self;
  final $Res Function(AiConfig) _then;

/// Create a copy of AiConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? configured = null,Object? model = null,Object? pricing = freezed,Object? pricingSourceUrl = null,Object? disclosedFields = null,}) {
  return _then(AiConfig(
configured: null == configured ? _self.configured : configured // ignore: cast_nullable_to_non_nullable
as bool,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,pricing: freezed == pricing ? _self.pricing : pricing // ignore: cast_nullable_to_non_nullable
as AiPricing?,pricingSourceUrl: null == pricingSourceUrl ? _self.pricingSourceUrl : pricingSourceUrl // ignore: cast_nullable_to_non_nullable
as String,disclosedFields: null == disclosedFields ? _self.disclosedFields : disclosedFields // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of AiConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiPricingCopyWith<$Res>? get pricing {
    if (_self.pricing == null) {
    return null;
  }

  return $AiPricingCopyWith<$Res>(_self.pricing!, (value) {
    return _then(_self.copyWith(pricing: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiConfig].
extension AiConfigPatterns on AiConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiConfig value)  $default,){
final _that = this;
switch (_that) {
case _AiConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiConfig value)?  $default,){
final _that = this;
switch (_that) {
case _AiConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool configured,  String model,  AiPricing? pricing, @JsonKey(name: 'pricing_source_url')  String pricingSourceUrl, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiConfig() when $default != null:
return $default(_that.configured,_that.model,_that.pricing,_that.pricingSourceUrl,_that.disclosedFields);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool configured,  String model,  AiPricing? pricing, @JsonKey(name: 'pricing_source_url')  String pricingSourceUrl, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields)  $default,) {final _that = this;
switch (_that) {
case _AiConfig():
return $default(_that.configured,_that.model,_that.pricing,_that.pricingSourceUrl,_that.disclosedFields);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool configured,  String model,  AiPricing? pricing, @JsonKey(name: 'pricing_source_url')  String pricingSourceUrl, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields)?  $default,) {final _that = this;
switch (_that) {
case _AiConfig() when $default != null:
return $default(_that.configured,_that.model,_that.pricing,_that.pricingSourceUrl,_that.disclosedFields);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiConfig implements AiConfig {
  const _AiConfig({required this.configured, this.model = '', this.pricing, @JsonKey(name: 'pricing_source_url') this.pricingSourceUrl = '', @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields = const <String>[]}): _disclosedFields = disclosedFields;
  factory _AiConfig.fromJson(Map<String, dynamic> json) => _$AiConfigFromJson(json);

@override final  bool configured;
@override@JsonKey() final  String model;
@override final  AiPricing? pricing;
@override@JsonKey(name: 'pricing_source_url') final  String pricingSourceUrl;
 final  List<String> _disclosedFields;
@override@JsonKey(name: 'disclosed_fields') List<String> get disclosedFields {
  if (_disclosedFields is EqualUnmodifiableListView) return _disclosedFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disclosedFields);
}


/// Create a copy of AiConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiConfigCopyWith<_AiConfig> get copyWith => __$AiConfigCopyWithImpl<_AiConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiConfig&&(identical(other.configured, configured) || other.configured == configured)&&(identical(other.model, model) || other.model == model)&&(identical(other.pricing, pricing) || other.pricing == pricing)&&(identical(other.pricingSourceUrl, pricingSourceUrl) || other.pricingSourceUrl == pricingSourceUrl)&&const DeepCollectionEquality().equals(other.disclosedFields, _disclosedFields));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,configured,model,pricing,pricingSourceUrl,const DeepCollectionEquality().hash(_disclosedFields));
}

@override
String toString() {
    return 'AiConfig(configured: $configured, model: $model, pricing: $pricing, pricingSourceUrl: $pricingSourceUrl, disclosedFields: $disclosedFields)';
}


}

/// @nodoc
abstract mixin class _$AiConfigCopyWith<$Res> implements $AiConfigCopyWith<$Res> {
  factory _$AiConfigCopyWith(_AiConfig value, $Res Function(_AiConfig) _then) = __$AiConfigCopyWithImpl;
@override @useResult
$Res call({
 bool configured, String model, AiPricing? pricing,@JsonKey(name: 'pricing_source_url') String pricingSourceUrl,@JsonKey(name: 'disclosed_fields') List<String> disclosedFields
});


@override $AiPricingCopyWith<$Res>? get pricing;

}
/// @nodoc
class __$AiConfigCopyWithImpl<$Res>
    implements _$AiConfigCopyWith<$Res> {
  __$AiConfigCopyWithImpl(this._self, this._then);

  final _AiConfig _self;
  final $Res Function(_AiConfig) _then;

/// Create a copy of AiConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? configured = null,Object? model = null,Object? pricing = freezed,Object? pricingSourceUrl = null,Object? disclosedFields = null,}) {
  return _then(_AiConfig(
configured: null == configured ? _self.configured : configured // ignore: cast_nullable_to_non_nullable
as bool,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,pricing: freezed == pricing ? _self.pricing : pricing // ignore: cast_nullable_to_non_nullable
as AiPricing?,pricingSourceUrl: null == pricingSourceUrl ? _self.pricingSourceUrl : pricingSourceUrl // ignore: cast_nullable_to_non_nullable
as String,disclosedFields: null == disclosedFields ? _self._disclosedFields : disclosedFields // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of AiConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiPricingCopyWith<$Res>? get pricing {
    if (_self.pricing == null) {
    return null;
  }

  return $AiPricingCopyWith<$Res>(_self.pricing!, (value) {
    return _then(_self.copyWith(pricing: value));
  });
}
}


/// @nodoc
mixin _$AiSuggestion {

@JsonKey(name: 'transaction_id') int get transactionId;@JsonKey(name: 'booking_date') String get bookingDate; String get counterparty; String get description; String get amount; String get currency;/// Null when the proposal is "this is a transfer" instead of a category.
 String? get category;@JsonKey(name: 'is_transfer') bool get isTransfer;/// What the transaction is labeled right now (relabel flow only) — lets
/// the review UI show "Groceries → Health". Null when uncategorized.
@JsonKey(name: 'current_category') String? get currentCategory;@JsonKey(name: 'is_new_category') bool get isNewCategory;
/// Create a copy of AiSuggestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSuggestionCopyWith<AiSuggestion> get copyWith => _$AiSuggestionCopyWithImpl<AiSuggestion>(this as AiSuggestion, _$identity);

  /// Serializes this AiSuggestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiSuggestion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSuggestion&&(identical(other.transactionId, _this.transactionId) || other.transactionId == _this.transactionId)&&(identical(other.bookingDate, _this.bookingDate) || other.bookingDate == _this.bookingDate)&&(identical(other.counterparty, _this.counterparty) || other.counterparty == _this.counterparty)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.currency, _this.currency) || other.currency == _this.currency)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.isTransfer, _this.isTransfer) || other.isTransfer == _this.isTransfer)&&(identical(other.currentCategory, _this.currentCategory) || other.currentCategory == _this.currentCategory)&&(identical(other.isNewCategory, _this.isNewCategory) || other.isNewCategory == _this.isNewCategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiSuggestion;
  return Object.hash(runtimeType,_this.transactionId,_this.bookingDate,_this.counterparty,_this.description,_this.amount,_this.currency,_this.category,_this.isTransfer,_this.currentCategory,_this.isNewCategory);
}

@override
String toString() {
  final _this = this as AiSuggestion;
  return 'AiSuggestion(transactionId: ${_this.transactionId}, bookingDate: ${_this.bookingDate}, counterparty: ${_this.counterparty}, description: ${_this.description}, amount: ${_this.amount}, currency: ${_this.currency}, category: ${_this.category}, isTransfer: ${_this.isTransfer}, currentCategory: ${_this.currentCategory}, isNewCategory: ${_this.isNewCategory})';
}


}

/// @nodoc
abstract mixin class $AiSuggestionCopyWith<$Res>  {
  factory $AiSuggestionCopyWith(AiSuggestion value, $Res Function(AiSuggestion) _then) = _$AiSuggestionCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'transaction_id') int transactionId,@JsonKey(name: 'booking_date') String bookingDate, String counterparty, String description, String amount, String currency, String? category,@JsonKey(name: 'is_transfer') bool isTransfer,@JsonKey(name: 'current_category') String? currentCategory,@JsonKey(name: 'is_new_category') bool isNewCategory
});




}
/// @nodoc
class _$AiSuggestionCopyWithImpl<$Res>
    implements $AiSuggestionCopyWith<$Res> {
  _$AiSuggestionCopyWithImpl(this._self, this._then);

  final AiSuggestion _self;
  final $Res Function(AiSuggestion) _then;

/// Create a copy of AiSuggestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? transactionId = null,Object? bookingDate = null,Object? counterparty = null,Object? description = null,Object? amount = null,Object? currency = null,Object? category = freezed,Object? isTransfer = null,Object? currentCategory = freezed,Object? isNewCategory = null,}) {
  return _then(AiSuggestion(
transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as int,bookingDate: null == bookingDate ? _self.bookingDate : bookingDate // ignore: cast_nullable_to_non_nullable
as String,counterparty: null == counterparty ? _self.counterparty : counterparty // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,isTransfer: null == isTransfer ? _self.isTransfer : isTransfer // ignore: cast_nullable_to_non_nullable
as bool,currentCategory: freezed == currentCategory ? _self.currentCategory : currentCategory // ignore: cast_nullable_to_non_nullable
as String?,isNewCategory: null == isNewCategory ? _self.isNewCategory : isNewCategory // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AiSuggestion].
extension AiSuggestionPatterns on AiSuggestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSuggestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSuggestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSuggestion value)  $default,){
final _that = this;
switch (_that) {
case _AiSuggestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSuggestion value)?  $default,){
final _that = this;
switch (_that) {
case _AiSuggestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'transaction_id')  int transactionId, @JsonKey(name: 'booking_date')  String bookingDate,  String counterparty,  String description,  String amount,  String currency,  String? category, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'current_category')  String? currentCategory, @JsonKey(name: 'is_new_category')  bool isNewCategory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSuggestion() when $default != null:
return $default(_that.transactionId,_that.bookingDate,_that.counterparty,_that.description,_that.amount,_that.currency,_that.category,_that.isTransfer,_that.currentCategory,_that.isNewCategory);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'transaction_id')  int transactionId, @JsonKey(name: 'booking_date')  String bookingDate,  String counterparty,  String description,  String amount,  String currency,  String? category, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'current_category')  String? currentCategory, @JsonKey(name: 'is_new_category')  bool isNewCategory)  $default,) {final _that = this;
switch (_that) {
case _AiSuggestion():
return $default(_that.transactionId,_that.bookingDate,_that.counterparty,_that.description,_that.amount,_that.currency,_that.category,_that.isTransfer,_that.currentCategory,_that.isNewCategory);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'transaction_id')  int transactionId, @JsonKey(name: 'booking_date')  String bookingDate,  String counterparty,  String description,  String amount,  String currency,  String? category, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'current_category')  String? currentCategory, @JsonKey(name: 'is_new_category')  bool isNewCategory)?  $default,) {final _that = this;
switch (_that) {
case _AiSuggestion() when $default != null:
return $default(_that.transactionId,_that.bookingDate,_that.counterparty,_that.description,_that.amount,_that.currency,_that.category,_that.isTransfer,_that.currentCategory,_that.isNewCategory);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiSuggestion implements AiSuggestion {
  const _AiSuggestion({@JsonKey(name: 'transaction_id') required this.transactionId, @JsonKey(name: 'booking_date') required this.bookingDate, this.counterparty = '', this.description = '', required this.amount, required this.currency, this.category, @JsonKey(name: 'is_transfer') this.isTransfer = false, @JsonKey(name: 'current_category') this.currentCategory, @JsonKey(name: 'is_new_category') this.isNewCategory = false});
  factory _AiSuggestion.fromJson(Map<String, dynamic> json) => _$AiSuggestionFromJson(json);

@override@JsonKey(name: 'transaction_id') final  int transactionId;
@override@JsonKey(name: 'booking_date') final  String bookingDate;
@override@JsonKey() final  String counterparty;
@override@JsonKey() final  String description;
@override final  String amount;
@override final  String currency;
/// Null when the proposal is "this is a transfer" instead of a category.
@override final  String? category;
@override@JsonKey(name: 'is_transfer') final  bool isTransfer;
/// What the transaction is labeled right now (relabel flow only) — lets
/// the review UI show "Groceries → Health". Null when uncategorized.
@override@JsonKey(name: 'current_category') final  String? currentCategory;
@override@JsonKey(name: 'is_new_category') final  bool isNewCategory;

/// Create a copy of AiSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSuggestionCopyWith<_AiSuggestion> get copyWith => __$AiSuggestionCopyWithImpl<_AiSuggestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiSuggestionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSuggestion&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.bookingDate, bookingDate) || other.bookingDate == bookingDate)&&(identical(other.counterparty, counterparty) || other.counterparty == counterparty)&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.category, category) || other.category == category)&&(identical(other.isTransfer, isTransfer) || other.isTransfer == isTransfer)&&(identical(other.currentCategory, currentCategory) || other.currentCategory == currentCategory)&&(identical(other.isNewCategory, isNewCategory) || other.isNewCategory == isNewCategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,transactionId,bookingDate,counterparty,description,amount,currency,category,isTransfer,currentCategory,isNewCategory);
}

@override
String toString() {
    return 'AiSuggestion(transactionId: $transactionId, bookingDate: $bookingDate, counterparty: $counterparty, description: $description, amount: $amount, currency: $currency, category: $category, isTransfer: $isTransfer, currentCategory: $currentCategory, isNewCategory: $isNewCategory)';
}


}

/// @nodoc
abstract mixin class _$AiSuggestionCopyWith<$Res> implements $AiSuggestionCopyWith<$Res> {
  factory _$AiSuggestionCopyWith(_AiSuggestion value, $Res Function(_AiSuggestion) _then) = __$AiSuggestionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'transaction_id') int transactionId,@JsonKey(name: 'booking_date') String bookingDate, String counterparty, String description, String amount, String currency, String? category,@JsonKey(name: 'is_transfer') bool isTransfer,@JsonKey(name: 'current_category') String? currentCategory,@JsonKey(name: 'is_new_category') bool isNewCategory
});




}
/// @nodoc
class __$AiSuggestionCopyWithImpl<$Res>
    implements _$AiSuggestionCopyWith<$Res> {
  __$AiSuggestionCopyWithImpl(this._self, this._then);

  final _AiSuggestion _self;
  final $Res Function(_AiSuggestion) _then;

/// Create a copy of AiSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? transactionId = null,Object? bookingDate = null,Object? counterparty = null,Object? description = null,Object? amount = null,Object? currency = null,Object? category = freezed,Object? isTransfer = null,Object? currentCategory = freezed,Object? isNewCategory = null,}) {
  return _then(_AiSuggestion(
transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as int,bookingDate: null == bookingDate ? _self.bookingDate : bookingDate // ignore: cast_nullable_to_non_nullable
as String,counterparty: null == counterparty ? _self.counterparty : counterparty // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,isTransfer: null == isTransfer ? _self.isTransfer : isTransfer // ignore: cast_nullable_to_non_nullable
as bool,currentCategory: freezed == currentCategory ? _self.currentCategory : currentCategory // ignore: cast_nullable_to_non_nullable
as String?,isNewCategory: null == isNewCategory ? _self.isNewCategory : isNewCategory // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AiRuleSuggestion {

@JsonKey(name: 'match_text') String get matchText;/// Null for transfer rules.
 String? get category;@JsonKey(name: 'is_regex') bool get isRegex;@JsonKey(name: 'is_transfer') bool get isTransfer;@JsonKey(name: 'is_new_category') bool get isNewCategory;/// Set when the proposal improves an existing rule in place (e.g. a regex
/// covering spellings the old match text missed) instead of adding one.
@JsonKey(name: 'replaces_rule_id') int? get replacesRuleId;@JsonKey(name: 'replaced_match_text') String? get replacedMatchText;/// Rules are first-match-wins: when an existing rule caused the mislabel,
/// the new rule must be inserted before it (relabel flow only).
@JsonKey(name: 'place_before_rule_id') int? get placeBeforeRuleId;@JsonKey(name: 'shadowed_match_text') String? get shadowedMatchText;
/// Create a copy of AiRuleSuggestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiRuleSuggestionCopyWith<AiRuleSuggestion> get copyWith => _$AiRuleSuggestionCopyWithImpl<AiRuleSuggestion>(this as AiRuleSuggestion, _$identity);

  /// Serializes this AiRuleSuggestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiRuleSuggestion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiRuleSuggestion&&(identical(other.matchText, _this.matchText) || other.matchText == _this.matchText)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.isRegex, _this.isRegex) || other.isRegex == _this.isRegex)&&(identical(other.isTransfer, _this.isTransfer) || other.isTransfer == _this.isTransfer)&&(identical(other.isNewCategory, _this.isNewCategory) || other.isNewCategory == _this.isNewCategory)&&(identical(other.replacesRuleId, _this.replacesRuleId) || other.replacesRuleId == _this.replacesRuleId)&&(identical(other.replacedMatchText, _this.replacedMatchText) || other.replacedMatchText == _this.replacedMatchText)&&(identical(other.placeBeforeRuleId, _this.placeBeforeRuleId) || other.placeBeforeRuleId == _this.placeBeforeRuleId)&&(identical(other.shadowedMatchText, _this.shadowedMatchText) || other.shadowedMatchText == _this.shadowedMatchText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiRuleSuggestion;
  return Object.hash(runtimeType,_this.matchText,_this.category,_this.isRegex,_this.isTransfer,_this.isNewCategory,_this.replacesRuleId,_this.replacedMatchText,_this.placeBeforeRuleId,_this.shadowedMatchText);
}

@override
String toString() {
  final _this = this as AiRuleSuggestion;
  return 'AiRuleSuggestion(matchText: ${_this.matchText}, category: ${_this.category}, isRegex: ${_this.isRegex}, isTransfer: ${_this.isTransfer}, isNewCategory: ${_this.isNewCategory}, replacesRuleId: ${_this.replacesRuleId}, replacedMatchText: ${_this.replacedMatchText}, placeBeforeRuleId: ${_this.placeBeforeRuleId}, shadowedMatchText: ${_this.shadowedMatchText})';
}


}

/// @nodoc
abstract mixin class $AiRuleSuggestionCopyWith<$Res>  {
  factory $AiRuleSuggestionCopyWith(AiRuleSuggestion value, $Res Function(AiRuleSuggestion) _then) = _$AiRuleSuggestionCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'match_text') String matchText, String? category,@JsonKey(name: 'is_regex') bool isRegex,@JsonKey(name: 'is_transfer') bool isTransfer,@JsonKey(name: 'is_new_category') bool isNewCategory,@JsonKey(name: 'replaces_rule_id') int? replacesRuleId,@JsonKey(name: 'replaced_match_text') String? replacedMatchText,@JsonKey(name: 'place_before_rule_id') int? placeBeforeRuleId,@JsonKey(name: 'shadowed_match_text') String? shadowedMatchText
});




}
/// @nodoc
class _$AiRuleSuggestionCopyWithImpl<$Res>
    implements $AiRuleSuggestionCopyWith<$Res> {
  _$AiRuleSuggestionCopyWithImpl(this._self, this._then);

  final AiRuleSuggestion _self;
  final $Res Function(AiRuleSuggestion) _then;

/// Create a copy of AiRuleSuggestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? matchText = null,Object? category = freezed,Object? isRegex = null,Object? isTransfer = null,Object? isNewCategory = null,Object? replacesRuleId = freezed,Object? replacedMatchText = freezed,Object? placeBeforeRuleId = freezed,Object? shadowedMatchText = freezed,}) {
  return _then(AiRuleSuggestion(
matchText: null == matchText ? _self.matchText : matchText // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,isRegex: null == isRegex ? _self.isRegex : isRegex // ignore: cast_nullable_to_non_nullable
as bool,isTransfer: null == isTransfer ? _self.isTransfer : isTransfer // ignore: cast_nullable_to_non_nullable
as bool,isNewCategory: null == isNewCategory ? _self.isNewCategory : isNewCategory // ignore: cast_nullable_to_non_nullable
as bool,replacesRuleId: freezed == replacesRuleId ? _self.replacesRuleId : replacesRuleId // ignore: cast_nullable_to_non_nullable
as int?,replacedMatchText: freezed == replacedMatchText ? _self.replacedMatchText : replacedMatchText // ignore: cast_nullable_to_non_nullable
as String?,placeBeforeRuleId: freezed == placeBeforeRuleId ? _self.placeBeforeRuleId : placeBeforeRuleId // ignore: cast_nullable_to_non_nullable
as int?,shadowedMatchText: freezed == shadowedMatchText ? _self.shadowedMatchText : shadowedMatchText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiRuleSuggestion].
extension AiRuleSuggestionPatterns on AiRuleSuggestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiRuleSuggestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiRuleSuggestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiRuleSuggestion value)  $default,){
final _that = this;
switch (_that) {
case _AiRuleSuggestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiRuleSuggestion value)?  $default,){
final _that = this;
switch (_that) {
case _AiRuleSuggestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'match_text')  String matchText,  String? category, @JsonKey(name: 'is_regex')  bool isRegex, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'is_new_category')  bool isNewCategory, @JsonKey(name: 'replaces_rule_id')  int? replacesRuleId, @JsonKey(name: 'replaced_match_text')  String? replacedMatchText, @JsonKey(name: 'place_before_rule_id')  int? placeBeforeRuleId, @JsonKey(name: 'shadowed_match_text')  String? shadowedMatchText)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiRuleSuggestion() when $default != null:
return $default(_that.matchText,_that.category,_that.isRegex,_that.isTransfer,_that.isNewCategory,_that.replacesRuleId,_that.replacedMatchText,_that.placeBeforeRuleId,_that.shadowedMatchText);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'match_text')  String matchText,  String? category, @JsonKey(name: 'is_regex')  bool isRegex, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'is_new_category')  bool isNewCategory, @JsonKey(name: 'replaces_rule_id')  int? replacesRuleId, @JsonKey(name: 'replaced_match_text')  String? replacedMatchText, @JsonKey(name: 'place_before_rule_id')  int? placeBeforeRuleId, @JsonKey(name: 'shadowed_match_text')  String? shadowedMatchText)  $default,) {final _that = this;
switch (_that) {
case _AiRuleSuggestion():
return $default(_that.matchText,_that.category,_that.isRegex,_that.isTransfer,_that.isNewCategory,_that.replacesRuleId,_that.replacedMatchText,_that.placeBeforeRuleId,_that.shadowedMatchText);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'match_text')  String matchText,  String? category, @JsonKey(name: 'is_regex')  bool isRegex, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'is_new_category')  bool isNewCategory, @JsonKey(name: 'replaces_rule_id')  int? replacesRuleId, @JsonKey(name: 'replaced_match_text')  String? replacedMatchText, @JsonKey(name: 'place_before_rule_id')  int? placeBeforeRuleId, @JsonKey(name: 'shadowed_match_text')  String? shadowedMatchText)?  $default,) {final _that = this;
switch (_that) {
case _AiRuleSuggestion() when $default != null:
return $default(_that.matchText,_that.category,_that.isRegex,_that.isTransfer,_that.isNewCategory,_that.replacesRuleId,_that.replacedMatchText,_that.placeBeforeRuleId,_that.shadowedMatchText);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiRuleSuggestion implements AiRuleSuggestion {
  const _AiRuleSuggestion({@JsonKey(name: 'match_text') required this.matchText, this.category, @JsonKey(name: 'is_regex') this.isRegex = false, @JsonKey(name: 'is_transfer') this.isTransfer = false, @JsonKey(name: 'is_new_category') this.isNewCategory = false, @JsonKey(name: 'replaces_rule_id') this.replacesRuleId, @JsonKey(name: 'replaced_match_text') this.replacedMatchText, @JsonKey(name: 'place_before_rule_id') this.placeBeforeRuleId, @JsonKey(name: 'shadowed_match_text') this.shadowedMatchText});
  factory _AiRuleSuggestion.fromJson(Map<String, dynamic> json) => _$AiRuleSuggestionFromJson(json);

@override@JsonKey(name: 'match_text') final  String matchText;
/// Null for transfer rules.
@override final  String? category;
@override@JsonKey(name: 'is_regex') final  bool isRegex;
@override@JsonKey(name: 'is_transfer') final  bool isTransfer;
@override@JsonKey(name: 'is_new_category') final  bool isNewCategory;
/// Set when the proposal improves an existing rule in place (e.g. a regex
/// covering spellings the old match text missed) instead of adding one.
@override@JsonKey(name: 'replaces_rule_id') final  int? replacesRuleId;
@override@JsonKey(name: 'replaced_match_text') final  String? replacedMatchText;
/// Rules are first-match-wins: when an existing rule caused the mislabel,
/// the new rule must be inserted before it (relabel flow only).
@override@JsonKey(name: 'place_before_rule_id') final  int? placeBeforeRuleId;
@override@JsonKey(name: 'shadowed_match_text') final  String? shadowedMatchText;

/// Create a copy of AiRuleSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiRuleSuggestionCopyWith<_AiRuleSuggestion> get copyWith => __$AiRuleSuggestionCopyWithImpl<_AiRuleSuggestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiRuleSuggestionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiRuleSuggestion&&(identical(other.matchText, matchText) || other.matchText == matchText)&&(identical(other.category, category) || other.category == category)&&(identical(other.isRegex, isRegex) || other.isRegex == isRegex)&&(identical(other.isTransfer, isTransfer) || other.isTransfer == isTransfer)&&(identical(other.isNewCategory, isNewCategory) || other.isNewCategory == isNewCategory)&&(identical(other.replacesRuleId, replacesRuleId) || other.replacesRuleId == replacesRuleId)&&(identical(other.replacedMatchText, replacedMatchText) || other.replacedMatchText == replacedMatchText)&&(identical(other.placeBeforeRuleId, placeBeforeRuleId) || other.placeBeforeRuleId == placeBeforeRuleId)&&(identical(other.shadowedMatchText, shadowedMatchText) || other.shadowedMatchText == shadowedMatchText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,matchText,category,isRegex,isTransfer,isNewCategory,replacesRuleId,replacedMatchText,placeBeforeRuleId,shadowedMatchText);
}

@override
String toString() {
    return 'AiRuleSuggestion(matchText: $matchText, category: $category, isRegex: $isRegex, isTransfer: $isTransfer, isNewCategory: $isNewCategory, replacesRuleId: $replacesRuleId, replacedMatchText: $replacedMatchText, placeBeforeRuleId: $placeBeforeRuleId, shadowedMatchText: $shadowedMatchText)';
}


}

/// @nodoc
abstract mixin class _$AiRuleSuggestionCopyWith<$Res> implements $AiRuleSuggestionCopyWith<$Res> {
  factory _$AiRuleSuggestionCopyWith(_AiRuleSuggestion value, $Res Function(_AiRuleSuggestion) _then) = __$AiRuleSuggestionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'match_text') String matchText, String? category,@JsonKey(name: 'is_regex') bool isRegex,@JsonKey(name: 'is_transfer') bool isTransfer,@JsonKey(name: 'is_new_category') bool isNewCategory,@JsonKey(name: 'replaces_rule_id') int? replacesRuleId,@JsonKey(name: 'replaced_match_text') String? replacedMatchText,@JsonKey(name: 'place_before_rule_id') int? placeBeforeRuleId,@JsonKey(name: 'shadowed_match_text') String? shadowedMatchText
});




}
/// @nodoc
class __$AiRuleSuggestionCopyWithImpl<$Res>
    implements _$AiRuleSuggestionCopyWith<$Res> {
  __$AiRuleSuggestionCopyWithImpl(this._self, this._then);

  final _AiRuleSuggestion _self;
  final $Res Function(_AiRuleSuggestion) _then;

/// Create a copy of AiRuleSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? matchText = null,Object? category = freezed,Object? isRegex = null,Object? isTransfer = null,Object? isNewCategory = null,Object? replacesRuleId = freezed,Object? replacedMatchText = freezed,Object? placeBeforeRuleId = freezed,Object? shadowedMatchText = freezed,}) {
  return _then(_AiRuleSuggestion(
matchText: null == matchText ? _self.matchText : matchText // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,isRegex: null == isRegex ? _self.isRegex : isRegex // ignore: cast_nullable_to_non_nullable
as bool,isTransfer: null == isTransfer ? _self.isTransfer : isTransfer // ignore: cast_nullable_to_non_nullable
as bool,isNewCategory: null == isNewCategory ? _self.isNewCategory : isNewCategory // ignore: cast_nullable_to_non_nullable
as bool,replacesRuleId: freezed == replacesRuleId ? _self.replacesRuleId : replacesRuleId // ignore: cast_nullable_to_non_nullable
as int?,replacedMatchText: freezed == replacedMatchText ? _self.replacedMatchText : replacedMatchText // ignore: cast_nullable_to_non_nullable
as String?,placeBeforeRuleId: freezed == placeBeforeRuleId ? _self.placeBeforeRuleId : placeBeforeRuleId // ignore: cast_nullable_to_non_nullable
as int?,shadowedMatchText: freezed == shadowedMatchText ? _self.shadowedMatchText : shadowedMatchText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AiConsolidatedRule {

@JsonKey(name: 'match_text') String get matchText; String get category;@JsonKey(name: 'spread_months') int get spreadMonths; List<int> get sources;
/// Create a copy of AiConsolidatedRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiConsolidatedRuleCopyWith<AiConsolidatedRule> get copyWith => _$AiConsolidatedRuleCopyWithImpl<AiConsolidatedRule>(this as AiConsolidatedRule, _$identity);

  /// Serializes this AiConsolidatedRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiConsolidatedRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiConsolidatedRule&&(identical(other.matchText, _this.matchText) || other.matchText == _this.matchText)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.spreadMonths, _this.spreadMonths) || other.spreadMonths == _this.spreadMonths)&&const DeepCollectionEquality().equals(other.sources, _this.sources));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiConsolidatedRule;
  return Object.hash(runtimeType,_this.matchText,_this.category,_this.spreadMonths,const DeepCollectionEquality().hash(_this.sources));
}

@override
String toString() {
  final _this = this as AiConsolidatedRule;
  return 'AiConsolidatedRule(matchText: ${_this.matchText}, category: ${_this.category}, spreadMonths: ${_this.spreadMonths}, sources: ${_this.sources})';
}


}

/// @nodoc
abstract mixin class $AiConsolidatedRuleCopyWith<$Res>  {
  factory $AiConsolidatedRuleCopyWith(AiConsolidatedRule value, $Res Function(AiConsolidatedRule) _then) = _$AiConsolidatedRuleCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'match_text') String matchText, String category,@JsonKey(name: 'spread_months') int spreadMonths, List<int> sources
});




}
/// @nodoc
class _$AiConsolidatedRuleCopyWithImpl<$Res>
    implements $AiConsolidatedRuleCopyWith<$Res> {
  _$AiConsolidatedRuleCopyWithImpl(this._self, this._then);

  final AiConsolidatedRule _self;
  final $Res Function(AiConsolidatedRule) _then;

/// Create a copy of AiConsolidatedRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? matchText = null,Object? category = null,Object? spreadMonths = null,Object? sources = null,}) {
  return _then(AiConsolidatedRule(
matchText: null == matchText ? _self.matchText : matchText // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,spreadMonths: null == spreadMonths ? _self.spreadMonths : spreadMonths // ignore: cast_nullable_to_non_nullable
as int,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [AiConsolidatedRule].
extension AiConsolidatedRulePatterns on AiConsolidatedRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiConsolidatedRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiConsolidatedRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiConsolidatedRule value)  $default,){
final _that = this;
switch (_that) {
case _AiConsolidatedRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiConsolidatedRule value)?  $default,){
final _that = this;
switch (_that) {
case _AiConsolidatedRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'match_text')  String matchText,  String category, @JsonKey(name: 'spread_months')  int spreadMonths,  List<int> sources)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiConsolidatedRule() when $default != null:
return $default(_that.matchText,_that.category,_that.spreadMonths,_that.sources);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'match_text')  String matchText,  String category, @JsonKey(name: 'spread_months')  int spreadMonths,  List<int> sources)  $default,) {final _that = this;
switch (_that) {
case _AiConsolidatedRule():
return $default(_that.matchText,_that.category,_that.spreadMonths,_that.sources);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'match_text')  String matchText,  String category, @JsonKey(name: 'spread_months')  int spreadMonths,  List<int> sources)?  $default,) {final _that = this;
switch (_that) {
case _AiConsolidatedRule() when $default != null:
return $default(_that.matchText,_that.category,_that.spreadMonths,_that.sources);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiConsolidatedRule implements AiConsolidatedRule {
  const _AiConsolidatedRule({@JsonKey(name: 'match_text') required this.matchText, required this.category, @JsonKey(name: 'spread_months') this.spreadMonths = 1,  List<int> sources = const <int>[]}): _sources = sources;
  factory _AiConsolidatedRule.fromJson(Map<String, dynamic> json) => _$AiConsolidatedRuleFromJson(json);

@override@JsonKey(name: 'match_text') final  String matchText;
@override final  String category;
@override@JsonKey(name: 'spread_months') final  int spreadMonths;
 final  List<int> _sources;
@override@JsonKey() List<int> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}


/// Create a copy of AiConsolidatedRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiConsolidatedRuleCopyWith<_AiConsolidatedRule> get copyWith => __$AiConsolidatedRuleCopyWithImpl<_AiConsolidatedRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiConsolidatedRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiConsolidatedRule&&(identical(other.matchText, matchText) || other.matchText == matchText)&&(identical(other.category, category) || other.category == category)&&(identical(other.spreadMonths, spreadMonths) || other.spreadMonths == spreadMonths)&&const DeepCollectionEquality().equals(other.sources, _sources));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,matchText,category,spreadMonths,const DeepCollectionEquality().hash(_sources));
}

@override
String toString() {
    return 'AiConsolidatedRule(matchText: $matchText, category: $category, spreadMonths: $spreadMonths, sources: $sources)';
}


}

/// @nodoc
abstract mixin class _$AiConsolidatedRuleCopyWith<$Res> implements $AiConsolidatedRuleCopyWith<$Res> {
  factory _$AiConsolidatedRuleCopyWith(_AiConsolidatedRule value, $Res Function(_AiConsolidatedRule) _then) = __$AiConsolidatedRuleCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'match_text') String matchText, String category,@JsonKey(name: 'spread_months') int spreadMonths, List<int> sources
});




}
/// @nodoc
class __$AiConsolidatedRuleCopyWithImpl<$Res>
    implements _$AiConsolidatedRuleCopyWith<$Res> {
  __$AiConsolidatedRuleCopyWithImpl(this._self, this._then);

  final _AiConsolidatedRule _self;
  final $Res Function(_AiConsolidatedRule) _then;

/// Create a copy of AiConsolidatedRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? matchText = null,Object? category = null,Object? spreadMonths = null,Object? sources = null,}) {
  return _then(_AiConsolidatedRule(
matchText: null == matchText ? _self.matchText : matchText // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,spreadMonths: null == spreadMonths ? _self.spreadMonths : spreadMonths // ignore: cast_nullable_to_non_nullable
as int,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}


/// @nodoc
mixin _$AiConsolidateResponse {

 List<AiConsolidatedRule> get rules;@JsonKey(name: 'before_count') int get beforeCount;@JsonKey(name: 'after_count') int get afterCount;@JsonKey(name: 'disclosed_fields') List<String> get disclosedFields; AiUsage? get usage;
/// Create a copy of AiConsolidateResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiConsolidateResponseCopyWith<AiConsolidateResponse> get copyWith => _$AiConsolidateResponseCopyWithImpl<AiConsolidateResponse>(this as AiConsolidateResponse, _$identity);

  /// Serializes this AiConsolidateResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiConsolidateResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiConsolidateResponse&&const DeepCollectionEquality().equals(other.rules, _this.rules)&&(identical(other.beforeCount, _this.beforeCount) || other.beforeCount == _this.beforeCount)&&(identical(other.afterCount, _this.afterCount) || other.afterCount == _this.afterCount)&&const DeepCollectionEquality().equals(other.disclosedFields, _this.disclosedFields)&&(identical(other.usage, _this.usage) || other.usage == _this.usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiConsolidateResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.rules),_this.beforeCount,_this.afterCount,const DeepCollectionEquality().hash(_this.disclosedFields),_this.usage);
}

@override
String toString() {
  final _this = this as AiConsolidateResponse;
  return 'AiConsolidateResponse(rules: ${_this.rules}, beforeCount: ${_this.beforeCount}, afterCount: ${_this.afterCount}, disclosedFields: ${_this.disclosedFields}, usage: ${_this.usage})';
}


}

/// @nodoc
abstract mixin class $AiConsolidateResponseCopyWith<$Res>  {
  factory $AiConsolidateResponseCopyWith(AiConsolidateResponse value, $Res Function(AiConsolidateResponse) _then) = _$AiConsolidateResponseCopyWithImpl;
@useResult
$Res call({
 List<AiConsolidatedRule> rules,@JsonKey(name: 'before_count') int beforeCount,@JsonKey(name: 'after_count') int afterCount,@JsonKey(name: 'disclosed_fields') List<String> disclosedFields, AiUsage? usage
});


$AiUsageCopyWith<$Res>? get usage;

}
/// @nodoc
class _$AiConsolidateResponseCopyWithImpl<$Res>
    implements $AiConsolidateResponseCopyWith<$Res> {
  _$AiConsolidateResponseCopyWithImpl(this._self, this._then);

  final AiConsolidateResponse _self;
  final $Res Function(AiConsolidateResponse) _then;

/// Create a copy of AiConsolidateResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rules = null,Object? beforeCount = null,Object? afterCount = null,Object? disclosedFields = null,Object? usage = freezed,}) {
  return _then(AiConsolidateResponse(
rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as List<AiConsolidatedRule>,beforeCount: null == beforeCount ? _self.beforeCount : beforeCount // ignore: cast_nullable_to_non_nullable
as int,afterCount: null == afterCount ? _self.afterCount : afterCount // ignore: cast_nullable_to_non_nullable
as int,disclosedFields: null == disclosedFields ? _self.disclosedFields : disclosedFields // ignore: cast_nullable_to_non_nullable
as List<String>,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as AiUsage?,
  ));
}
/// Create a copy of AiConsolidateResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiUsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $AiUsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiConsolidateResponse].
extension AiConsolidateResponsePatterns on AiConsolidateResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiConsolidateResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiConsolidateResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiConsolidateResponse value)  $default,){
final _that = this;
switch (_that) {
case _AiConsolidateResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiConsolidateResponse value)?  $default,){
final _that = this;
switch (_that) {
case _AiConsolidateResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AiConsolidatedRule> rules, @JsonKey(name: 'before_count')  int beforeCount, @JsonKey(name: 'after_count')  int afterCount, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields,  AiUsage? usage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiConsolidateResponse() when $default != null:
return $default(_that.rules,_that.beforeCount,_that.afterCount,_that.disclosedFields,_that.usage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AiConsolidatedRule> rules, @JsonKey(name: 'before_count')  int beforeCount, @JsonKey(name: 'after_count')  int afterCount, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields,  AiUsage? usage)  $default,) {final _that = this;
switch (_that) {
case _AiConsolidateResponse():
return $default(_that.rules,_that.beforeCount,_that.afterCount,_that.disclosedFields,_that.usage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AiConsolidatedRule> rules, @JsonKey(name: 'before_count')  int beforeCount, @JsonKey(name: 'after_count')  int afterCount, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields,  AiUsage? usage)?  $default,) {final _that = this;
switch (_that) {
case _AiConsolidateResponse() when $default != null:
return $default(_that.rules,_that.beforeCount,_that.afterCount,_that.disclosedFields,_that.usage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiConsolidateResponse implements AiConsolidateResponse {
  const _AiConsolidateResponse({ List<AiConsolidatedRule> rules = const <AiConsolidatedRule>[], @JsonKey(name: 'before_count') this.beforeCount = 0, @JsonKey(name: 'after_count') this.afterCount = 0, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields = const <String>[], this.usage}): _rules = rules,_disclosedFields = disclosedFields;
  factory _AiConsolidateResponse.fromJson(Map<String, dynamic> json) => _$AiConsolidateResponseFromJson(json);

 final  List<AiConsolidatedRule> _rules;
@override@JsonKey() List<AiConsolidatedRule> get rules {
  if (_rules is EqualUnmodifiableListView) return _rules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rules);
}

@override@JsonKey(name: 'before_count') final  int beforeCount;
@override@JsonKey(name: 'after_count') final  int afterCount;
 final  List<String> _disclosedFields;
@override@JsonKey(name: 'disclosed_fields') List<String> get disclosedFields {
  if (_disclosedFields is EqualUnmodifiableListView) return _disclosedFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disclosedFields);
}

@override final  AiUsage? usage;

/// Create a copy of AiConsolidateResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiConsolidateResponseCopyWith<_AiConsolidateResponse> get copyWith => __$AiConsolidateResponseCopyWithImpl<_AiConsolidateResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiConsolidateResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiConsolidateResponse&&const DeepCollectionEquality().equals(other.rules, _rules)&&(identical(other.beforeCount, beforeCount) || other.beforeCount == beforeCount)&&(identical(other.afterCount, afterCount) || other.afterCount == afterCount)&&const DeepCollectionEquality().equals(other.disclosedFields, _disclosedFields)&&(identical(other.usage, usage) || other.usage == usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_rules),beforeCount,afterCount,const DeepCollectionEquality().hash(_disclosedFields),usage);
}

@override
String toString() {
    return 'AiConsolidateResponse(rules: $rules, beforeCount: $beforeCount, afterCount: $afterCount, disclosedFields: $disclosedFields, usage: $usage)';
}


}

/// @nodoc
abstract mixin class _$AiConsolidateResponseCopyWith<$Res> implements $AiConsolidateResponseCopyWith<$Res> {
  factory _$AiConsolidateResponseCopyWith(_AiConsolidateResponse value, $Res Function(_AiConsolidateResponse) _then) = __$AiConsolidateResponseCopyWithImpl;
@override @useResult
$Res call({
 List<AiConsolidatedRule> rules,@JsonKey(name: 'before_count') int beforeCount,@JsonKey(name: 'after_count') int afterCount,@JsonKey(name: 'disclosed_fields') List<String> disclosedFields, AiUsage? usage
});


@override $AiUsageCopyWith<$Res>? get usage;

}
/// @nodoc
class __$AiConsolidateResponseCopyWithImpl<$Res>
    implements _$AiConsolidateResponseCopyWith<$Res> {
  __$AiConsolidateResponseCopyWithImpl(this._self, this._then);

  final _AiConsolidateResponse _self;
  final $Res Function(_AiConsolidateResponse) _then;

/// Create a copy of AiConsolidateResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rules = null,Object? beforeCount = null,Object? afterCount = null,Object? disclosedFields = null,Object? usage = freezed,}) {
  return _then(_AiConsolidateResponse(
rules: null == rules ? _self._rules : rules // ignore: cast_nullable_to_non_nullable
as List<AiConsolidatedRule>,beforeCount: null == beforeCount ? _self.beforeCount : beforeCount // ignore: cast_nullable_to_non_nullable
as int,afterCount: null == afterCount ? _self.afterCount : afterCount // ignore: cast_nullable_to_non_nullable
as int,disclosedFields: null == disclosedFields ? _self._disclosedFields : disclosedFields // ignore: cast_nullable_to_non_nullable
as List<String>,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as AiUsage?,
  ));
}

/// Create a copy of AiConsolidateResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiUsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $AiUsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}
}


/// @nodoc
mixin _$AiUsage {

@JsonKey(name: 'input_tokens') int get inputTokens;@JsonKey(name: 'output_tokens') int get outputTokens;@JsonKey(name: 'estimated_cost_usd') double? get estimatedCostUsd;
/// Create a copy of AiUsage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiUsageCopyWith<AiUsage> get copyWith => _$AiUsageCopyWithImpl<AiUsage>(this as AiUsage, _$identity);

  /// Serializes this AiUsage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiUsage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiUsage&&(identical(other.inputTokens, _this.inputTokens) || other.inputTokens == _this.inputTokens)&&(identical(other.outputTokens, _this.outputTokens) || other.outputTokens == _this.outputTokens)&&(identical(other.estimatedCostUsd, _this.estimatedCostUsd) || other.estimatedCostUsd == _this.estimatedCostUsd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiUsage;
  return Object.hash(runtimeType,_this.inputTokens,_this.outputTokens,_this.estimatedCostUsd);
}

@override
String toString() {
  final _this = this as AiUsage;
  return 'AiUsage(inputTokens: ${_this.inputTokens}, outputTokens: ${_this.outputTokens}, estimatedCostUsd: ${_this.estimatedCostUsd})';
}


}

/// @nodoc
abstract mixin class $AiUsageCopyWith<$Res>  {
  factory $AiUsageCopyWith(AiUsage value, $Res Function(AiUsage) _then) = _$AiUsageCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'input_tokens') int inputTokens,@JsonKey(name: 'output_tokens') int outputTokens,@JsonKey(name: 'estimated_cost_usd') double? estimatedCostUsd
});




}
/// @nodoc
class _$AiUsageCopyWithImpl<$Res>
    implements $AiUsageCopyWith<$Res> {
  _$AiUsageCopyWithImpl(this._self, this._then);

  final AiUsage _self;
  final $Res Function(AiUsage) _then;

/// Create a copy of AiUsage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? inputTokens = null,Object? outputTokens = null,Object? estimatedCostUsd = freezed,}) {
  return _then(AiUsage(
inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,estimatedCostUsd: freezed == estimatedCostUsd ? _self.estimatedCostUsd : estimatedCostUsd // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiUsage].
extension AiUsagePatterns on AiUsage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiUsage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiUsage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiUsage value)  $default,){
final _that = this;
switch (_that) {
case _AiUsage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiUsage value)?  $default,){
final _that = this;
switch (_that) {
case _AiUsage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'input_tokens')  int inputTokens, @JsonKey(name: 'output_tokens')  int outputTokens, @JsonKey(name: 'estimated_cost_usd')  double? estimatedCostUsd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiUsage() when $default != null:
return $default(_that.inputTokens,_that.outputTokens,_that.estimatedCostUsd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'input_tokens')  int inputTokens, @JsonKey(name: 'output_tokens')  int outputTokens, @JsonKey(name: 'estimated_cost_usd')  double? estimatedCostUsd)  $default,) {final _that = this;
switch (_that) {
case _AiUsage():
return $default(_that.inputTokens,_that.outputTokens,_that.estimatedCostUsd);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'input_tokens')  int inputTokens, @JsonKey(name: 'output_tokens')  int outputTokens, @JsonKey(name: 'estimated_cost_usd')  double? estimatedCostUsd)?  $default,) {final _that = this;
switch (_that) {
case _AiUsage() when $default != null:
return $default(_that.inputTokens,_that.outputTokens,_that.estimatedCostUsd);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiUsage implements AiUsage {
  const _AiUsage({@JsonKey(name: 'input_tokens') this.inputTokens = 0, @JsonKey(name: 'output_tokens') this.outputTokens = 0, @JsonKey(name: 'estimated_cost_usd') this.estimatedCostUsd});
  factory _AiUsage.fromJson(Map<String, dynamic> json) => _$AiUsageFromJson(json);

@override@JsonKey(name: 'input_tokens') final  int inputTokens;
@override@JsonKey(name: 'output_tokens') final  int outputTokens;
@override@JsonKey(name: 'estimated_cost_usd') final  double? estimatedCostUsd;

/// Create a copy of AiUsage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiUsageCopyWith<_AiUsage> get copyWith => __$AiUsageCopyWithImpl<_AiUsage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiUsageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiUsage&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.estimatedCostUsd, estimatedCostUsd) || other.estimatedCostUsd == estimatedCostUsd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,inputTokens,outputTokens,estimatedCostUsd);
}

@override
String toString() {
    return 'AiUsage(inputTokens: $inputTokens, outputTokens: $outputTokens, estimatedCostUsd: $estimatedCostUsd)';
}


}

/// @nodoc
abstract mixin class _$AiUsageCopyWith<$Res> implements $AiUsageCopyWith<$Res> {
  factory _$AiUsageCopyWith(_AiUsage value, $Res Function(_AiUsage) _then) = __$AiUsageCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'input_tokens') int inputTokens,@JsonKey(name: 'output_tokens') int outputTokens,@JsonKey(name: 'estimated_cost_usd') double? estimatedCostUsd
});




}
/// @nodoc
class __$AiUsageCopyWithImpl<$Res>
    implements _$AiUsageCopyWith<$Res> {
  __$AiUsageCopyWithImpl(this._self, this._then);

  final _AiUsage _self;
  final $Res Function(_AiUsage) _then;

/// Create a copy of AiUsage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? inputTokens = null,Object? outputTokens = null,Object? estimatedCostUsd = freezed,}) {
  return _then(_AiUsage(
inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,estimatedCostUsd: freezed == estimatedCostUsd ? _self.estimatedCostUsd : estimatedCostUsd // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$AiSuggestResponse {

 List<AiSuggestion> get suggestions; List<AiRuleSuggestion> get rules;@JsonKey(name: 'sent_count') int get sentCount;@JsonKey(name: 'total_uncategorized') int get totalUncategorized;@JsonKey(name: 'disclosed_fields') List<String> get disclosedFields; AiUsage? get usage;
/// Create a copy of AiSuggestResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSuggestResponseCopyWith<AiSuggestResponse> get copyWith => _$AiSuggestResponseCopyWithImpl<AiSuggestResponse>(this as AiSuggestResponse, _$identity);

  /// Serializes this AiSuggestResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiSuggestResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSuggestResponse&&const DeepCollectionEquality().equals(other.suggestions, _this.suggestions)&&const DeepCollectionEquality().equals(other.rules, _this.rules)&&(identical(other.sentCount, _this.sentCount) || other.sentCount == _this.sentCount)&&(identical(other.totalUncategorized, _this.totalUncategorized) || other.totalUncategorized == _this.totalUncategorized)&&const DeepCollectionEquality().equals(other.disclosedFields, _this.disclosedFields)&&(identical(other.usage, _this.usage) || other.usage == _this.usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiSuggestResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.suggestions),const DeepCollectionEquality().hash(_this.rules),_this.sentCount,_this.totalUncategorized,const DeepCollectionEquality().hash(_this.disclosedFields),_this.usage);
}

@override
String toString() {
  final _this = this as AiSuggestResponse;
  return 'AiSuggestResponse(suggestions: ${_this.suggestions}, rules: ${_this.rules}, sentCount: ${_this.sentCount}, totalUncategorized: ${_this.totalUncategorized}, disclosedFields: ${_this.disclosedFields}, usage: ${_this.usage})';
}


}

/// @nodoc
abstract mixin class $AiSuggestResponseCopyWith<$Res>  {
  factory $AiSuggestResponseCopyWith(AiSuggestResponse value, $Res Function(AiSuggestResponse) _then) = _$AiSuggestResponseCopyWithImpl;
@useResult
$Res call({
 List<AiSuggestion> suggestions, List<AiRuleSuggestion> rules,@JsonKey(name: 'sent_count') int sentCount,@JsonKey(name: 'total_uncategorized') int totalUncategorized,@JsonKey(name: 'disclosed_fields') List<String> disclosedFields, AiUsage? usage
});


$AiUsageCopyWith<$Res>? get usage;

}
/// @nodoc
class _$AiSuggestResponseCopyWithImpl<$Res>
    implements $AiSuggestResponseCopyWith<$Res> {
  _$AiSuggestResponseCopyWithImpl(this._self, this._then);

  final AiSuggestResponse _self;
  final $Res Function(AiSuggestResponse) _then;

/// Create a copy of AiSuggestResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? suggestions = null,Object? rules = null,Object? sentCount = null,Object? totalUncategorized = null,Object? disclosedFields = null,Object? usage = freezed,}) {
  return _then(AiSuggestResponse(
suggestions: null == suggestions ? _self.suggestions : suggestions // ignore: cast_nullable_to_non_nullable
as List<AiSuggestion>,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as List<AiRuleSuggestion>,sentCount: null == sentCount ? _self.sentCount : sentCount // ignore: cast_nullable_to_non_nullable
as int,totalUncategorized: null == totalUncategorized ? _self.totalUncategorized : totalUncategorized // ignore: cast_nullable_to_non_nullable
as int,disclosedFields: null == disclosedFields ? _self.disclosedFields : disclosedFields // ignore: cast_nullable_to_non_nullable
as List<String>,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as AiUsage?,
  ));
}
/// Create a copy of AiSuggestResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiUsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $AiUsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiSuggestResponse].
extension AiSuggestResponsePatterns on AiSuggestResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSuggestResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSuggestResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSuggestResponse value)  $default,){
final _that = this;
switch (_that) {
case _AiSuggestResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSuggestResponse value)?  $default,){
final _that = this;
switch (_that) {
case _AiSuggestResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AiSuggestion> suggestions,  List<AiRuleSuggestion> rules, @JsonKey(name: 'sent_count')  int sentCount, @JsonKey(name: 'total_uncategorized')  int totalUncategorized, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields,  AiUsage? usage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSuggestResponse() when $default != null:
return $default(_that.suggestions,_that.rules,_that.sentCount,_that.totalUncategorized,_that.disclosedFields,_that.usage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AiSuggestion> suggestions,  List<AiRuleSuggestion> rules, @JsonKey(name: 'sent_count')  int sentCount, @JsonKey(name: 'total_uncategorized')  int totalUncategorized, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields,  AiUsage? usage)  $default,) {final _that = this;
switch (_that) {
case _AiSuggestResponse():
return $default(_that.suggestions,_that.rules,_that.sentCount,_that.totalUncategorized,_that.disclosedFields,_that.usage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AiSuggestion> suggestions,  List<AiRuleSuggestion> rules, @JsonKey(name: 'sent_count')  int sentCount, @JsonKey(name: 'total_uncategorized')  int totalUncategorized, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields,  AiUsage? usage)?  $default,) {final _that = this;
switch (_that) {
case _AiSuggestResponse() when $default != null:
return $default(_that.suggestions,_that.rules,_that.sentCount,_that.totalUncategorized,_that.disclosedFields,_that.usage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiSuggestResponse implements AiSuggestResponse {
  const _AiSuggestResponse({ List<AiSuggestion> suggestions = const <AiSuggestion>[],  List<AiRuleSuggestion> rules = const <AiRuleSuggestion>[], @JsonKey(name: 'sent_count') this.sentCount = 0, @JsonKey(name: 'total_uncategorized') this.totalUncategorized = 0, @JsonKey(name: 'disclosed_fields')  List<String> disclosedFields = const <String>[], this.usage}): _suggestions = suggestions,_rules = rules,_disclosedFields = disclosedFields;
  factory _AiSuggestResponse.fromJson(Map<String, dynamic> json) => _$AiSuggestResponseFromJson(json);

 final  List<AiSuggestion> _suggestions;
@override@JsonKey() List<AiSuggestion> get suggestions {
  if (_suggestions is EqualUnmodifiableListView) return _suggestions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_suggestions);
}

 final  List<AiRuleSuggestion> _rules;
@override@JsonKey() List<AiRuleSuggestion> get rules {
  if (_rules is EqualUnmodifiableListView) return _rules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rules);
}

@override@JsonKey(name: 'sent_count') final  int sentCount;
@override@JsonKey(name: 'total_uncategorized') final  int totalUncategorized;
 final  List<String> _disclosedFields;
@override@JsonKey(name: 'disclosed_fields') List<String> get disclosedFields {
  if (_disclosedFields is EqualUnmodifiableListView) return _disclosedFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disclosedFields);
}

@override final  AiUsage? usage;

/// Create a copy of AiSuggestResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSuggestResponseCopyWith<_AiSuggestResponse> get copyWith => __$AiSuggestResponseCopyWithImpl<_AiSuggestResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiSuggestResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSuggestResponse&&const DeepCollectionEquality().equals(other.suggestions, _suggestions)&&const DeepCollectionEquality().equals(other.rules, _rules)&&(identical(other.sentCount, sentCount) || other.sentCount == sentCount)&&(identical(other.totalUncategorized, totalUncategorized) || other.totalUncategorized == totalUncategorized)&&const DeepCollectionEquality().equals(other.disclosedFields, _disclosedFields)&&(identical(other.usage, usage) || other.usage == usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_suggestions),const DeepCollectionEquality().hash(_rules),sentCount,totalUncategorized,const DeepCollectionEquality().hash(_disclosedFields),usage);
}

@override
String toString() {
    return 'AiSuggestResponse(suggestions: $suggestions, rules: $rules, sentCount: $sentCount, totalUncategorized: $totalUncategorized, disclosedFields: $disclosedFields, usage: $usage)';
}


}

/// @nodoc
abstract mixin class _$AiSuggestResponseCopyWith<$Res> implements $AiSuggestResponseCopyWith<$Res> {
  factory _$AiSuggestResponseCopyWith(_AiSuggestResponse value, $Res Function(_AiSuggestResponse) _then) = __$AiSuggestResponseCopyWithImpl;
@override @useResult
$Res call({
 List<AiSuggestion> suggestions, List<AiRuleSuggestion> rules,@JsonKey(name: 'sent_count') int sentCount,@JsonKey(name: 'total_uncategorized') int totalUncategorized,@JsonKey(name: 'disclosed_fields') List<String> disclosedFields, AiUsage? usage
});


@override $AiUsageCopyWith<$Res>? get usage;

}
/// @nodoc
class __$AiSuggestResponseCopyWithImpl<$Res>
    implements _$AiSuggestResponseCopyWith<$Res> {
  __$AiSuggestResponseCopyWithImpl(this._self, this._then);

  final _AiSuggestResponse _self;
  final $Res Function(_AiSuggestResponse) _then;

/// Create a copy of AiSuggestResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? suggestions = null,Object? rules = null,Object? sentCount = null,Object? totalUncategorized = null,Object? disclosedFields = null,Object? usage = freezed,}) {
  return _then(_AiSuggestResponse(
suggestions: null == suggestions ? _self._suggestions : suggestions // ignore: cast_nullable_to_non_nullable
as List<AiSuggestion>,rules: null == rules ? _self._rules : rules // ignore: cast_nullable_to_non_nullable
as List<AiRuleSuggestion>,sentCount: null == sentCount ? _self.sentCount : sentCount // ignore: cast_nullable_to_non_nullable
as int,totalUncategorized: null == totalUncategorized ? _self.totalUncategorized : totalUncategorized // ignore: cast_nullable_to_non_nullable
as int,disclosedFields: null == disclosedFields ? _self._disclosedFields : disclosedFields // ignore: cast_nullable_to_non_nullable
as List<String>,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as AiUsage?,
  ));
}

/// Create a copy of AiSuggestResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiUsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $AiUsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}
}

// dart format on
