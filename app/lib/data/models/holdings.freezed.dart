// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'holdings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Holding {

 String get isin; String get symbol; String get name;@JsonKey(name: 'asset_class') String get assetClass; double get quantity;@JsonKey(name: 'value_base_currency') double get valueBaseCurrency;@JsonKey(name: 'price_base_currency') double? get priceBaseCurrency; double get percentage; List<String> get accounts;
/// Create a copy of Holding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HoldingCopyWith<Holding> get copyWith => _$HoldingCopyWithImpl<Holding>(this as Holding, _$identity);

  /// Serializes this Holding to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Holding;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Holding&&(identical(other.isin, _this.isin) || other.isin == _this.isin)&&(identical(other.symbol, _this.symbol) || other.symbol == _this.symbol)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.assetClass, _this.assetClass) || other.assetClass == _this.assetClass)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.valueBaseCurrency, _this.valueBaseCurrency) || other.valueBaseCurrency == _this.valueBaseCurrency)&&(identical(other.priceBaseCurrency, _this.priceBaseCurrency) || other.priceBaseCurrency == _this.priceBaseCurrency)&&(identical(other.percentage, _this.percentage) || other.percentage == _this.percentage)&&const DeepCollectionEquality().equals(other.accounts, _this.accounts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Holding;
  return Object.hash(runtimeType,_this.isin,_this.symbol,_this.name,_this.assetClass,_this.quantity,_this.valueBaseCurrency,_this.priceBaseCurrency,_this.percentage,const DeepCollectionEquality().hash(_this.accounts));
}

@override
String toString() {
  final _this = this as Holding;
  return 'Holding(isin: ${_this.isin}, symbol: ${_this.symbol}, name: ${_this.name}, assetClass: ${_this.assetClass}, quantity: ${_this.quantity}, valueBaseCurrency: ${_this.valueBaseCurrency}, priceBaseCurrency: ${_this.priceBaseCurrency}, percentage: ${_this.percentage}, accounts: ${_this.accounts})';
}


}

/// @nodoc
abstract mixin class $HoldingCopyWith<$Res>  {
  factory $HoldingCopyWith(Holding value, $Res Function(Holding) _then) = _$HoldingCopyWithImpl;
@useResult
$Res call({
 String isin, String symbol, String name,@JsonKey(name: 'asset_class') String assetClass, double quantity,@JsonKey(name: 'value_base_currency') double valueBaseCurrency,@JsonKey(name: 'price_base_currency') double? priceBaseCurrency, double percentage, List<String> accounts
});




}
/// @nodoc
class _$HoldingCopyWithImpl<$Res>
    implements $HoldingCopyWith<$Res> {
  _$HoldingCopyWithImpl(this._self, this._then);

  final Holding _self;
  final $Res Function(Holding) _then;

/// Create a copy of Holding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isin = null,Object? symbol = null,Object? name = null,Object? assetClass = null,Object? quantity = null,Object? valueBaseCurrency = null,Object? priceBaseCurrency = freezed,Object? percentage = null,Object? accounts = null,}) {
  return _then(Holding(
isin: null == isin ? _self.isin : isin // ignore: cast_nullable_to_non_nullable
as String,symbol: null == symbol ? _self.symbol : symbol // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assetClass: null == assetClass ? _self.assetClass : assetClass // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,valueBaseCurrency: null == valueBaseCurrency ? _self.valueBaseCurrency : valueBaseCurrency // ignore: cast_nullable_to_non_nullable
as double,priceBaseCurrency: freezed == priceBaseCurrency ? _self.priceBaseCurrency : priceBaseCurrency // ignore: cast_nullable_to_non_nullable
as double?,percentage: null == percentage ? _self.percentage : percentage // ignore: cast_nullable_to_non_nullable
as double,accounts: null == accounts ? _self.accounts : accounts // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Holding].
extension HoldingPatterns on Holding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Holding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Holding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Holding value)  $default,){
final _that = this;
switch (_that) {
case _Holding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Holding value)?  $default,){
final _that = this;
switch (_that) {
case _Holding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String isin,  String symbol,  String name, @JsonKey(name: 'asset_class')  String assetClass,  double quantity, @JsonKey(name: 'value_base_currency')  double valueBaseCurrency, @JsonKey(name: 'price_base_currency')  double? priceBaseCurrency,  double percentage,  List<String> accounts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Holding() when $default != null:
return $default(_that.isin,_that.symbol,_that.name,_that.assetClass,_that.quantity,_that.valueBaseCurrency,_that.priceBaseCurrency,_that.percentage,_that.accounts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String isin,  String symbol,  String name, @JsonKey(name: 'asset_class')  String assetClass,  double quantity, @JsonKey(name: 'value_base_currency')  double valueBaseCurrency, @JsonKey(name: 'price_base_currency')  double? priceBaseCurrency,  double percentage,  List<String> accounts)  $default,) {final _that = this;
switch (_that) {
case _Holding():
return $default(_that.isin,_that.symbol,_that.name,_that.assetClass,_that.quantity,_that.valueBaseCurrency,_that.priceBaseCurrency,_that.percentage,_that.accounts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String isin,  String symbol,  String name, @JsonKey(name: 'asset_class')  String assetClass,  double quantity, @JsonKey(name: 'value_base_currency')  double valueBaseCurrency, @JsonKey(name: 'price_base_currency')  double? priceBaseCurrency,  double percentage,  List<String> accounts)?  $default,) {final _that = this;
switch (_that) {
case _Holding() when $default != null:
return $default(_that.isin,_that.symbol,_that.name,_that.assetClass,_that.quantity,_that.valueBaseCurrency,_that.priceBaseCurrency,_that.percentage,_that.accounts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Holding implements Holding {
  const _Holding({this.isin = '', this.symbol = '', required this.name, @JsonKey(name: 'asset_class') required this.assetClass, required this.quantity, @JsonKey(name: 'value_base_currency') required this.valueBaseCurrency, @JsonKey(name: 'price_base_currency') this.priceBaseCurrency, required this.percentage, required  List<String> accounts}): _accounts = accounts;
  factory _Holding.fromJson(Map<String, dynamic> json) => _$HoldingFromJson(json);

@override@JsonKey() final  String isin;
@override@JsonKey() final  String symbol;
@override final  String name;
@override@JsonKey(name: 'asset_class') final  String assetClass;
@override final  double quantity;
@override@JsonKey(name: 'value_base_currency') final  double valueBaseCurrency;
@override@JsonKey(name: 'price_base_currency') final  double? priceBaseCurrency;
@override final  double percentage;
 final  List<String> _accounts;
@override List<String> get accounts {
  if (_accounts is EqualUnmodifiableListView) return _accounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accounts);
}


/// Create a copy of Holding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HoldingCopyWith<_Holding> get copyWith => __$HoldingCopyWithImpl<_Holding>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HoldingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Holding&&(identical(other.isin, isin) || other.isin == isin)&&(identical(other.symbol, symbol) || other.symbol == symbol)&&(identical(other.name, name) || other.name == name)&&(identical(other.assetClass, assetClass) || other.assetClass == assetClass)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.valueBaseCurrency, valueBaseCurrency) || other.valueBaseCurrency == valueBaseCurrency)&&(identical(other.priceBaseCurrency, priceBaseCurrency) || other.priceBaseCurrency == priceBaseCurrency)&&(identical(other.percentage, percentage) || other.percentage == percentage)&&const DeepCollectionEquality().equals(other.accounts, _accounts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isin,symbol,name,assetClass,quantity,valueBaseCurrency,priceBaseCurrency,percentage,const DeepCollectionEquality().hash(_accounts));
}

@override
String toString() {
    return 'Holding(isin: $isin, symbol: $symbol, name: $name, assetClass: $assetClass, quantity: $quantity, valueBaseCurrency: $valueBaseCurrency, priceBaseCurrency: $priceBaseCurrency, percentage: $percentage, accounts: $accounts)';
}


}

/// @nodoc
abstract mixin class _$HoldingCopyWith<$Res> implements $HoldingCopyWith<$Res> {
  factory _$HoldingCopyWith(_Holding value, $Res Function(_Holding) _then) = __$HoldingCopyWithImpl;
@override @useResult
$Res call({
 String isin, String symbol, String name,@JsonKey(name: 'asset_class') String assetClass, double quantity,@JsonKey(name: 'value_base_currency') double valueBaseCurrency,@JsonKey(name: 'price_base_currency') double? priceBaseCurrency, double percentage, List<String> accounts
});




}
/// @nodoc
class __$HoldingCopyWithImpl<$Res>
    implements _$HoldingCopyWith<$Res> {
  __$HoldingCopyWithImpl(this._self, this._then);

  final _Holding _self;
  final $Res Function(_Holding) _then;

/// Create a copy of Holding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isin = null,Object? symbol = null,Object? name = null,Object? assetClass = null,Object? quantity = null,Object? valueBaseCurrency = null,Object? priceBaseCurrency = freezed,Object? percentage = null,Object? accounts = null,}) {
  return _then(_Holding(
isin: null == isin ? _self.isin : isin // ignore: cast_nullable_to_non_nullable
as String,symbol: null == symbol ? _self.symbol : symbol // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assetClass: null == assetClass ? _self.assetClass : assetClass // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,valueBaseCurrency: null == valueBaseCurrency ? _self.valueBaseCurrency : valueBaseCurrency // ignore: cast_nullable_to_non_nullable
as double,priceBaseCurrency: freezed == priceBaseCurrency ? _self.priceBaseCurrency : priceBaseCurrency // ignore: cast_nullable_to_non_nullable
as double?,percentage: null == percentage ? _self.percentage : percentage // ignore: cast_nullable_to_non_nullable
as double,accounts: null == accounts ? _self._accounts : accounts // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$HoldingsReport {

@JsonKey(name: 'base_currency') String get baseCurrency;@JsonKey(name: 'as_of') String? get asOf; double get total; List<Holding> get holdings;
/// Create a copy of HoldingsReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HoldingsReportCopyWith<HoldingsReport> get copyWith => _$HoldingsReportCopyWithImpl<HoldingsReport>(this as HoldingsReport, _$identity);

  /// Serializes this HoldingsReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HoldingsReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HoldingsReport&&(identical(other.baseCurrency, _this.baseCurrency) || other.baseCurrency == _this.baseCurrency)&&(identical(other.asOf, _this.asOf) || other.asOf == _this.asOf)&&(identical(other.total, _this.total) || other.total == _this.total)&&const DeepCollectionEquality().equals(other.holdings, _this.holdings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HoldingsReport;
  return Object.hash(runtimeType,_this.baseCurrency,_this.asOf,_this.total,const DeepCollectionEquality().hash(_this.holdings));
}

@override
String toString() {
  final _this = this as HoldingsReport;
  return 'HoldingsReport(baseCurrency: ${_this.baseCurrency}, asOf: ${_this.asOf}, total: ${_this.total}, holdings: ${_this.holdings})';
}


}

/// @nodoc
abstract mixin class $HoldingsReportCopyWith<$Res>  {
  factory $HoldingsReportCopyWith(HoldingsReport value, $Res Function(HoldingsReport) _then) = _$HoldingsReportCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'base_currency') String baseCurrency,@JsonKey(name: 'as_of') String? asOf, double total, List<Holding> holdings
});




}
/// @nodoc
class _$HoldingsReportCopyWithImpl<$Res>
    implements $HoldingsReportCopyWith<$Res> {
  _$HoldingsReportCopyWithImpl(this._self, this._then);

  final HoldingsReport _self;
  final $Res Function(HoldingsReport) _then;

/// Create a copy of HoldingsReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? baseCurrency = null,Object? asOf = freezed,Object? total = null,Object? holdings = null,}) {
  return _then(HoldingsReport(
baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,asOf: freezed == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as String?,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,holdings: null == holdings ? _self.holdings : holdings // ignore: cast_nullable_to_non_nullable
as List<Holding>,
  ));
}

}


/// Adds pattern-matching-related methods to [HoldingsReport].
extension HoldingsReportPatterns on HoldingsReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HoldingsReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HoldingsReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HoldingsReport value)  $default,){
final _that = this;
switch (_that) {
case _HoldingsReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HoldingsReport value)?  $default,){
final _that = this;
switch (_that) {
case _HoldingsReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'as_of')  String? asOf,  double total,  List<Holding> holdings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HoldingsReport() when $default != null:
return $default(_that.baseCurrency,_that.asOf,_that.total,_that.holdings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'as_of')  String? asOf,  double total,  List<Holding> holdings)  $default,) {final _that = this;
switch (_that) {
case _HoldingsReport():
return $default(_that.baseCurrency,_that.asOf,_that.total,_that.holdings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'base_currency')  String baseCurrency, @JsonKey(name: 'as_of')  String? asOf,  double total,  List<Holding> holdings)?  $default,) {final _that = this;
switch (_that) {
case _HoldingsReport() when $default != null:
return $default(_that.baseCurrency,_that.asOf,_that.total,_that.holdings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HoldingsReport implements HoldingsReport {
  const _HoldingsReport({@JsonKey(name: 'base_currency') required this.baseCurrency, @JsonKey(name: 'as_of') this.asOf, required this.total, required  List<Holding> holdings}): _holdings = holdings;
  factory _HoldingsReport.fromJson(Map<String, dynamic> json) => _$HoldingsReportFromJson(json);

@override@JsonKey(name: 'base_currency') final  String baseCurrency;
@override@JsonKey(name: 'as_of') final  String? asOf;
@override final  double total;
 final  List<Holding> _holdings;
@override List<Holding> get holdings {
  if (_holdings is EqualUnmodifiableListView) return _holdings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_holdings);
}


/// Create a copy of HoldingsReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HoldingsReportCopyWith<_HoldingsReport> get copyWith => __$HoldingsReportCopyWithImpl<_HoldingsReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HoldingsReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HoldingsReport&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.asOf, asOf) || other.asOf == asOf)&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other.holdings, _holdings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,baseCurrency,asOf,total,const DeepCollectionEquality().hash(_holdings));
}

@override
String toString() {
    return 'HoldingsReport(baseCurrency: $baseCurrency, asOf: $asOf, total: $total, holdings: $holdings)';
}


}

/// @nodoc
abstract mixin class _$HoldingsReportCopyWith<$Res> implements $HoldingsReportCopyWith<$Res> {
  factory _$HoldingsReportCopyWith(_HoldingsReport value, $Res Function(_HoldingsReport) _then) = __$HoldingsReportCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'base_currency') String baseCurrency,@JsonKey(name: 'as_of') String? asOf, double total, List<Holding> holdings
});




}
/// @nodoc
class __$HoldingsReportCopyWithImpl<$Res>
    implements _$HoldingsReportCopyWith<$Res> {
  __$HoldingsReportCopyWithImpl(this._self, this._then);

  final _HoldingsReport _self;
  final $Res Function(_HoldingsReport) _then;

/// Create a copy of HoldingsReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? baseCurrency = null,Object? asOf = freezed,Object? total = null,Object? holdings = null,}) {
  return _then(_HoldingsReport(
baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,asOf: freezed == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as String?,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,holdings: null == holdings ? _self._holdings : holdings // ignore: cast_nullable_to_non_nullable
as List<Holding>,
  ));
}


}

// dart format on
