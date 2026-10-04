// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spending.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpendingMonth {

 String get month; double get income; double get expenses; double get net;@JsonKey(name: 'by_category') Map<String, double> get byCategory;
/// Create a copy of SpendingMonth
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpendingMonthCopyWith<SpendingMonth> get copyWith => _$SpendingMonthCopyWithImpl<SpendingMonth>(this as SpendingMonth, _$identity);

  /// Serializes this SpendingMonth to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpendingMonth;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpendingMonth&&(identical(other.month, _this.month) || other.month == _this.month)&&(identical(other.income, _this.income) || other.income == _this.income)&&(identical(other.expenses, _this.expenses) || other.expenses == _this.expenses)&&(identical(other.net, _this.net) || other.net == _this.net)&&const DeepCollectionEquality().equals(other.byCategory, _this.byCategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpendingMonth;
  return Object.hash(runtimeType,_this.month,_this.income,_this.expenses,_this.net,const DeepCollectionEquality().hash(_this.byCategory));
}

@override
String toString() {
  final _this = this as SpendingMonth;
  return 'SpendingMonth(month: ${_this.month}, income: ${_this.income}, expenses: ${_this.expenses}, net: ${_this.net}, byCategory: ${_this.byCategory})';
}


}

/// @nodoc
abstract mixin class $SpendingMonthCopyWith<$Res>  {
  factory $SpendingMonthCopyWith(SpendingMonth value, $Res Function(SpendingMonth) _then) = _$SpendingMonthCopyWithImpl;
@useResult
$Res call({
 String month, double income, double expenses, double net,@JsonKey(name: 'by_category') Map<String, double> byCategory
});




}
/// @nodoc
class _$SpendingMonthCopyWithImpl<$Res>
    implements $SpendingMonthCopyWith<$Res> {
  _$SpendingMonthCopyWithImpl(this._self, this._then);

  final SpendingMonth _self;
  final $Res Function(SpendingMonth) _then;

/// Create a copy of SpendingMonth
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? month = null,Object? income = null,Object? expenses = null,Object? net = null,Object? byCategory = null,}) {
  return _then(SpendingMonth(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as String,income: null == income ? _self.income : income // ignore: cast_nullable_to_non_nullable
as double,expenses: null == expenses ? _self.expenses : expenses // ignore: cast_nullable_to_non_nullable
as double,net: null == net ? _self.net : net // ignore: cast_nullable_to_non_nullable
as double,byCategory: null == byCategory ? _self.byCategory : byCategory // ignore: cast_nullable_to_non_nullable
as Map<String, double>,
  ));
}

}


/// Adds pattern-matching-related methods to [SpendingMonth].
extension SpendingMonthPatterns on SpendingMonth {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpendingMonth value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpendingMonth() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpendingMonth value)  $default,){
final _that = this;
switch (_that) {
case _SpendingMonth():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpendingMonth value)?  $default,){
final _that = this;
switch (_that) {
case _SpendingMonth() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String month,  double income,  double expenses,  double net, @JsonKey(name: 'by_category')  Map<String, double> byCategory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpendingMonth() when $default != null:
return $default(_that.month,_that.income,_that.expenses,_that.net,_that.byCategory);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String month,  double income,  double expenses,  double net, @JsonKey(name: 'by_category')  Map<String, double> byCategory)  $default,) {final _that = this;
switch (_that) {
case _SpendingMonth():
return $default(_that.month,_that.income,_that.expenses,_that.net,_that.byCategory);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String month,  double income,  double expenses,  double net, @JsonKey(name: 'by_category')  Map<String, double> byCategory)?  $default,) {final _that = this;
switch (_that) {
case _SpendingMonth() when $default != null:
return $default(_that.month,_that.income,_that.expenses,_that.net,_that.byCategory);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpendingMonth implements SpendingMonth {
  const _SpendingMonth({required this.month, required this.income, required this.expenses, required this.net, @JsonKey(name: 'by_category')  Map<String, double> byCategory = const <String, double>{}}): _byCategory = byCategory;
  factory _SpendingMonth.fromJson(Map<String, dynamic> json) => _$SpendingMonthFromJson(json);

@override final  String month;
@override final  double income;
@override final  double expenses;
@override final  double net;
 final  Map<String, double> _byCategory;
@override@JsonKey(name: 'by_category') Map<String, double> get byCategory {
  if (_byCategory is EqualUnmodifiableMapView) return _byCategory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_byCategory);
}


/// Create a copy of SpendingMonth
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpendingMonthCopyWith<_SpendingMonth> get copyWith => __$SpendingMonthCopyWithImpl<_SpendingMonth>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpendingMonthToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpendingMonth&&(identical(other.month, month) || other.month == month)&&(identical(other.income, income) || other.income == income)&&(identical(other.expenses, expenses) || other.expenses == expenses)&&(identical(other.net, net) || other.net == net)&&const DeepCollectionEquality().equals(other.byCategory, _byCategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,month,income,expenses,net,const DeepCollectionEquality().hash(_byCategory));
}

@override
String toString() {
    return 'SpendingMonth(month: $month, income: $income, expenses: $expenses, net: $net, byCategory: $byCategory)';
}


}

/// @nodoc
abstract mixin class _$SpendingMonthCopyWith<$Res> implements $SpendingMonthCopyWith<$Res> {
  factory _$SpendingMonthCopyWith(_SpendingMonth value, $Res Function(_SpendingMonth) _then) = __$SpendingMonthCopyWithImpl;
@override @useResult
$Res call({
 String month, double income, double expenses, double net,@JsonKey(name: 'by_category') Map<String, double> byCategory
});




}
/// @nodoc
class __$SpendingMonthCopyWithImpl<$Res>
    implements _$SpendingMonthCopyWith<$Res> {
  __$SpendingMonthCopyWithImpl(this._self, this._then);

  final _SpendingMonth _self;
  final $Res Function(_SpendingMonth) _then;

/// Create a copy of SpendingMonth
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? month = null,Object? income = null,Object? expenses = null,Object? net = null,Object? byCategory = null,}) {
  return _then(_SpendingMonth(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as String,income: null == income ? _self.income : income // ignore: cast_nullable_to_non_nullable
as double,expenses: null == expenses ? _self.expenses : expenses // ignore: cast_nullable_to_non_nullable
as double,net: null == net ? _self.net : net // ignore: cast_nullable_to_non_nullable
as double,byCategory: null == byCategory ? _self._byCategory : byCategory // ignore: cast_nullable_to_non_nullable
as Map<String, double>,
  ));
}


}


/// @nodoc
mixin _$SpendingReport {

 String get mode;@JsonKey(name: 'base_currency') String get baseCurrency; String get granularity; List<String> get categories; List<SpendingMonth> get months; Map<String, double> get budgets;
/// Create a copy of SpendingReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpendingReportCopyWith<SpendingReport> get copyWith => _$SpendingReportCopyWithImpl<SpendingReport>(this as SpendingReport, _$identity);

  /// Serializes this SpendingReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpendingReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpendingReport&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.baseCurrency, _this.baseCurrency) || other.baseCurrency == _this.baseCurrency)&&(identical(other.granularity, _this.granularity) || other.granularity == _this.granularity)&&const DeepCollectionEquality().equals(other.categories, _this.categories)&&const DeepCollectionEquality().equals(other.months, _this.months)&&const DeepCollectionEquality().equals(other.budgets, _this.budgets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpendingReport;
  return Object.hash(runtimeType,_this.mode,_this.baseCurrency,_this.granularity,const DeepCollectionEquality().hash(_this.categories),const DeepCollectionEquality().hash(_this.months),const DeepCollectionEquality().hash(_this.budgets));
}

@override
String toString() {
  final _this = this as SpendingReport;
  return 'SpendingReport(mode: ${_this.mode}, baseCurrency: ${_this.baseCurrency}, granularity: ${_this.granularity}, categories: ${_this.categories}, months: ${_this.months}, budgets: ${_this.budgets})';
}


}

/// @nodoc
abstract mixin class $SpendingReportCopyWith<$Res>  {
  factory $SpendingReportCopyWith(SpendingReport value, $Res Function(SpendingReport) _then) = _$SpendingReportCopyWithImpl;
@useResult
$Res call({
 String mode,@JsonKey(name: 'base_currency') String baseCurrency, String granularity, List<String> categories, List<SpendingMonth> months, Map<String, double> budgets
});




}
/// @nodoc
class _$SpendingReportCopyWithImpl<$Res>
    implements $SpendingReportCopyWith<$Res> {
  _$SpendingReportCopyWithImpl(this._self, this._then);

  final SpendingReport _self;
  final $Res Function(SpendingReport) _then;

/// Create a copy of SpendingReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? baseCurrency = null,Object? granularity = null,Object? categories = null,Object? months = null,Object? budgets = null,}) {
  return _then(SpendingReport(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,granularity: null == granularity ? _self.granularity : granularity // ignore: cast_nullable_to_non_nullable
as String,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<String>,months: null == months ? _self.months : months // ignore: cast_nullable_to_non_nullable
as List<SpendingMonth>,budgets: null == budgets ? _self.budgets : budgets // ignore: cast_nullable_to_non_nullable
as Map<String, double>,
  ));
}

}


/// Adds pattern-matching-related methods to [SpendingReport].
extension SpendingReportPatterns on SpendingReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpendingReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpendingReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpendingReport value)  $default,){
final _that = this;
switch (_that) {
case _SpendingReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpendingReport value)?  $default,){
final _that = this;
switch (_that) {
case _SpendingReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mode, @JsonKey(name: 'base_currency')  String baseCurrency,  String granularity,  List<String> categories,  List<SpendingMonth> months,  Map<String, double> budgets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpendingReport() when $default != null:
return $default(_that.mode,_that.baseCurrency,_that.granularity,_that.categories,_that.months,_that.budgets);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mode, @JsonKey(name: 'base_currency')  String baseCurrency,  String granularity,  List<String> categories,  List<SpendingMonth> months,  Map<String, double> budgets)  $default,) {final _that = this;
switch (_that) {
case _SpendingReport():
return $default(_that.mode,_that.baseCurrency,_that.granularity,_that.categories,_that.months,_that.budgets);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mode, @JsonKey(name: 'base_currency')  String baseCurrency,  String granularity,  List<String> categories,  List<SpendingMonth> months,  Map<String, double> budgets)?  $default,) {final _that = this;
switch (_that) {
case _SpendingReport() when $default != null:
return $default(_that.mode,_that.baseCurrency,_that.granularity,_that.categories,_that.months,_that.budgets);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpendingReport implements SpendingReport {
  const _SpendingReport({required this.mode, @JsonKey(name: 'base_currency') required this.baseCurrency, this.granularity = 'month',  List<String> categories = const <String>[],  List<SpendingMonth> months = const <SpendingMonth>[],  Map<String, double> budgets = const <String, double>{}}): _categories = categories,_months = months,_budgets = budgets;
  factory _SpendingReport.fromJson(Map<String, dynamic> json) => _$SpendingReportFromJson(json);

@override final  String mode;
@override@JsonKey(name: 'base_currency') final  String baseCurrency;
@override@JsonKey() final  String granularity;
 final  List<String> _categories;
@override@JsonKey() List<String> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  List<SpendingMonth> _months;
@override@JsonKey() List<SpendingMonth> get months {
  if (_months is EqualUnmodifiableListView) return _months;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_months);
}

 final  Map<String, double> _budgets;
@override@JsonKey() Map<String, double> get budgets {
  if (_budgets is EqualUnmodifiableMapView) return _budgets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_budgets);
}


/// Create a copy of SpendingReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpendingReportCopyWith<_SpendingReport> get copyWith => __$SpendingReportCopyWithImpl<_SpendingReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpendingReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpendingReport&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.granularity, granularity) || other.granularity == granularity)&&const DeepCollectionEquality().equals(other.categories, _categories)&&const DeepCollectionEquality().equals(other.months, _months)&&const DeepCollectionEquality().equals(other.budgets, _budgets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mode,baseCurrency,granularity,const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_months),const DeepCollectionEquality().hash(_budgets));
}

@override
String toString() {
    return 'SpendingReport(mode: $mode, baseCurrency: $baseCurrency, granularity: $granularity, categories: $categories, months: $months, budgets: $budgets)';
}


}

/// @nodoc
abstract mixin class _$SpendingReportCopyWith<$Res> implements $SpendingReportCopyWith<$Res> {
  factory _$SpendingReportCopyWith(_SpendingReport value, $Res Function(_SpendingReport) _then) = __$SpendingReportCopyWithImpl;
@override @useResult
$Res call({
 String mode,@JsonKey(name: 'base_currency') String baseCurrency, String granularity, List<String> categories, List<SpendingMonth> months, Map<String, double> budgets
});




}
/// @nodoc
class __$SpendingReportCopyWithImpl<$Res>
    implements _$SpendingReportCopyWith<$Res> {
  __$SpendingReportCopyWithImpl(this._self, this._then);

  final _SpendingReport _self;
  final $Res Function(_SpendingReport) _then;

/// Create a copy of SpendingReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? baseCurrency = null,Object? granularity = null,Object? categories = null,Object? months = null,Object? budgets = null,}) {
  return _then(_SpendingReport(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,granularity: null == granularity ? _self.granularity : granularity // ignore: cast_nullable_to_non_nullable
as String,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<String>,months: null == months ? _self._months : months // ignore: cast_nullable_to_non_nullable
as List<SpendingMonth>,budgets: null == budgets ? _self._budgets : budgets // ignore: cast_nullable_to_non_nullable
as Map<String, double>,
  ));
}


}

// dart format on
