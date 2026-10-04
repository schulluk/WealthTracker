// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transactions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TransactionRecord {

 int get id; int get account;@JsonKey(name: 'booking_date') String get bookingDate;@JsonKey(name: 'value_date') String? get valueDate; String get amount; String get currency; String get counterparty; String get description; String get source; int? get category;@JsonKey(name: 'category_name') String? get categoryName;@JsonKey(name: 'spread_months') int get spreadMonths;@JsonKey(name: 'is_transfer') bool get isTransfer;
/// Create a copy of TransactionRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionRecordCopyWith<TransactionRecord> get copyWith => _$TransactionRecordCopyWithImpl<TransactionRecord>(this as TransactionRecord, _$identity);

  /// Serializes this TransactionRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TransactionRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.account, _this.account) || other.account == _this.account)&&(identical(other.bookingDate, _this.bookingDate) || other.bookingDate == _this.bookingDate)&&(identical(other.valueDate, _this.valueDate) || other.valueDate == _this.valueDate)&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.currency, _this.currency) || other.currency == _this.currency)&&(identical(other.counterparty, _this.counterparty) || other.counterparty == _this.counterparty)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.categoryName, _this.categoryName) || other.categoryName == _this.categoryName)&&(identical(other.spreadMonths, _this.spreadMonths) || other.spreadMonths == _this.spreadMonths)&&(identical(other.isTransfer, _this.isTransfer) || other.isTransfer == _this.isTransfer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TransactionRecord;
  return Object.hash(runtimeType,_this.id,_this.account,_this.bookingDate,_this.valueDate,_this.amount,_this.currency,_this.counterparty,_this.description,_this.source,_this.category,_this.categoryName,_this.spreadMonths,_this.isTransfer);
}

@override
String toString() {
  final _this = this as TransactionRecord;
  return 'TransactionRecord(id: ${_this.id}, account: ${_this.account}, bookingDate: ${_this.bookingDate}, valueDate: ${_this.valueDate}, amount: ${_this.amount}, currency: ${_this.currency}, counterparty: ${_this.counterparty}, description: ${_this.description}, source: ${_this.source}, category: ${_this.category}, categoryName: ${_this.categoryName}, spreadMonths: ${_this.spreadMonths}, isTransfer: ${_this.isTransfer})';
}


}

/// @nodoc
abstract mixin class $TransactionRecordCopyWith<$Res>  {
  factory $TransactionRecordCopyWith(TransactionRecord value, $Res Function(TransactionRecord) _then) = _$TransactionRecordCopyWithImpl;
@useResult
$Res call({
 int id, int account,@JsonKey(name: 'booking_date') String bookingDate,@JsonKey(name: 'value_date') String? valueDate, String amount, String currency, String counterparty, String description, String source, int? category,@JsonKey(name: 'category_name') String? categoryName,@JsonKey(name: 'spread_months') int spreadMonths,@JsonKey(name: 'is_transfer') bool isTransfer
});




}
/// @nodoc
class _$TransactionRecordCopyWithImpl<$Res>
    implements $TransactionRecordCopyWith<$Res> {
  _$TransactionRecordCopyWithImpl(this._self, this._then);

  final TransactionRecord _self;
  final $Res Function(TransactionRecord) _then;

/// Create a copy of TransactionRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? account = null,Object? bookingDate = null,Object? valueDate = freezed,Object? amount = null,Object? currency = null,Object? counterparty = null,Object? description = null,Object? source = null,Object? category = freezed,Object? categoryName = freezed,Object? spreadMonths = null,Object? isTransfer = null,}) {
  return _then(TransactionRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,account: null == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as int,bookingDate: null == bookingDate ? _self.bookingDate : bookingDate // ignore: cast_nullable_to_non_nullable
as String,valueDate: freezed == valueDate ? _self.valueDate : valueDate // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,counterparty: null == counterparty ? _self.counterparty : counterparty // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,spreadMonths: null == spreadMonths ? _self.spreadMonths : spreadMonths // ignore: cast_nullable_to_non_nullable
as int,isTransfer: null == isTransfer ? _self.isTransfer : isTransfer // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TransactionRecord].
extension TransactionRecordPatterns on TransactionRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionRecord value)  $default,){
final _that = this;
switch (_that) {
case _TransactionRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionRecord value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int account, @JsonKey(name: 'booking_date')  String bookingDate, @JsonKey(name: 'value_date')  String? valueDate,  String amount,  String currency,  String counterparty,  String description,  String source,  int? category, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'spread_months')  int spreadMonths, @JsonKey(name: 'is_transfer')  bool isTransfer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionRecord() when $default != null:
return $default(_that.id,_that.account,_that.bookingDate,_that.valueDate,_that.amount,_that.currency,_that.counterparty,_that.description,_that.source,_that.category,_that.categoryName,_that.spreadMonths,_that.isTransfer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int account, @JsonKey(name: 'booking_date')  String bookingDate, @JsonKey(name: 'value_date')  String? valueDate,  String amount,  String currency,  String counterparty,  String description,  String source,  int? category, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'spread_months')  int spreadMonths, @JsonKey(name: 'is_transfer')  bool isTransfer)  $default,) {final _that = this;
switch (_that) {
case _TransactionRecord():
return $default(_that.id,_that.account,_that.bookingDate,_that.valueDate,_that.amount,_that.currency,_that.counterparty,_that.description,_that.source,_that.category,_that.categoryName,_that.spreadMonths,_that.isTransfer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int account, @JsonKey(name: 'booking_date')  String bookingDate, @JsonKey(name: 'value_date')  String? valueDate,  String amount,  String currency,  String counterparty,  String description,  String source,  int? category, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'spread_months')  int spreadMonths, @JsonKey(name: 'is_transfer')  bool isTransfer)?  $default,) {final _that = this;
switch (_that) {
case _TransactionRecord() when $default != null:
return $default(_that.id,_that.account,_that.bookingDate,_that.valueDate,_that.amount,_that.currency,_that.counterparty,_that.description,_that.source,_that.category,_that.categoryName,_that.spreadMonths,_that.isTransfer);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransactionRecord implements TransactionRecord {
  const _TransactionRecord({required this.id, required this.account, @JsonKey(name: 'booking_date') required this.bookingDate, @JsonKey(name: 'value_date') this.valueDate, required this.amount, required this.currency, this.counterparty = '', this.description = '', this.source = '', this.category, @JsonKey(name: 'category_name') this.categoryName, @JsonKey(name: 'spread_months') this.spreadMonths = 1, @JsonKey(name: 'is_transfer') this.isTransfer = false});
  factory _TransactionRecord.fromJson(Map<String, dynamic> json) => _$TransactionRecordFromJson(json);

@override final  int id;
@override final  int account;
@override@JsonKey(name: 'booking_date') final  String bookingDate;
@override@JsonKey(name: 'value_date') final  String? valueDate;
@override final  String amount;
@override final  String currency;
@override@JsonKey() final  String counterparty;
@override@JsonKey() final  String description;
@override@JsonKey() final  String source;
@override final  int? category;
@override@JsonKey(name: 'category_name') final  String? categoryName;
@override@JsonKey(name: 'spread_months') final  int spreadMonths;
@override@JsonKey(name: 'is_transfer') final  bool isTransfer;

/// Create a copy of TransactionRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionRecordCopyWith<_TransactionRecord> get copyWith => __$TransactionRecordCopyWithImpl<_TransactionRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.account, account) || other.account == account)&&(identical(other.bookingDate, bookingDate) || other.bookingDate == bookingDate)&&(identical(other.valueDate, valueDate) || other.valueDate == valueDate)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.counterparty, counterparty) || other.counterparty == counterparty)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.category, category) || other.category == category)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.spreadMonths, spreadMonths) || other.spreadMonths == spreadMonths)&&(identical(other.isTransfer, isTransfer) || other.isTransfer == isTransfer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,account,bookingDate,valueDate,amount,currency,counterparty,description,source,category,categoryName,spreadMonths,isTransfer);
}

@override
String toString() {
    return 'TransactionRecord(id: $id, account: $account, bookingDate: $bookingDate, valueDate: $valueDate, amount: $amount, currency: $currency, counterparty: $counterparty, description: $description, source: $source, category: $category, categoryName: $categoryName, spreadMonths: $spreadMonths, isTransfer: $isTransfer)';
}


}

/// @nodoc
abstract mixin class _$TransactionRecordCopyWith<$Res> implements $TransactionRecordCopyWith<$Res> {
  factory _$TransactionRecordCopyWith(_TransactionRecord value, $Res Function(_TransactionRecord) _then) = __$TransactionRecordCopyWithImpl;
@override @useResult
$Res call({
 int id, int account,@JsonKey(name: 'booking_date') String bookingDate,@JsonKey(name: 'value_date') String? valueDate, String amount, String currency, String counterparty, String description, String source, int? category,@JsonKey(name: 'category_name') String? categoryName,@JsonKey(name: 'spread_months') int spreadMonths,@JsonKey(name: 'is_transfer') bool isTransfer
});




}
/// @nodoc
class __$TransactionRecordCopyWithImpl<$Res>
    implements _$TransactionRecordCopyWith<$Res> {
  __$TransactionRecordCopyWithImpl(this._self, this._then);

  final _TransactionRecord _self;
  final $Res Function(_TransactionRecord) _then;

/// Create a copy of TransactionRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? account = null,Object? bookingDate = null,Object? valueDate = freezed,Object? amount = null,Object? currency = null,Object? counterparty = null,Object? description = null,Object? source = null,Object? category = freezed,Object? categoryName = freezed,Object? spreadMonths = null,Object? isTransfer = null,}) {
  return _then(_TransactionRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,account: null == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as int,bookingDate: null == bookingDate ? _self.bookingDate : bookingDate // ignore: cast_nullable_to_non_nullable
as String,valueDate: freezed == valueDate ? _self.valueDate : valueDate // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,counterparty: null == counterparty ? _self.counterparty : counterparty // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,spreadMonths: null == spreadMonths ? _self.spreadMonths : spreadMonths // ignore: cast_nullable_to_non_nullable
as int,isTransfer: null == isTransfer ? _self.isTransfer : isTransfer // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TransactionPage {

 int get count; List<TransactionRecord> get results;
/// Create a copy of TransactionPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionPageCopyWith<TransactionPage> get copyWith => _$TransactionPageCopyWithImpl<TransactionPage>(this as TransactionPage, _$identity);

  /// Serializes this TransactionPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TransactionPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionPage&&(identical(other.count, _this.count) || other.count == _this.count)&&const DeepCollectionEquality().equals(other.results, _this.results));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TransactionPage;
  return Object.hash(runtimeType,_this.count,const DeepCollectionEquality().hash(_this.results));
}

@override
String toString() {
  final _this = this as TransactionPage;
  return 'TransactionPage(count: ${_this.count}, results: ${_this.results})';
}


}

/// @nodoc
abstract mixin class $TransactionPageCopyWith<$Res>  {
  factory $TransactionPageCopyWith(TransactionPage value, $Res Function(TransactionPage) _then) = _$TransactionPageCopyWithImpl;
@useResult
$Res call({
 int count, List<TransactionRecord> results
});




}
/// @nodoc
class _$TransactionPageCopyWithImpl<$Res>
    implements $TransactionPageCopyWith<$Res> {
  _$TransactionPageCopyWithImpl(this._self, this._then);

  final TransactionPage _self;
  final $Res Function(TransactionPage) _then;

/// Create a copy of TransactionPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? count = null,Object? results = null,}) {
  return _then(TransactionPage(
count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,results: null == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<TransactionRecord>,
  ));
}

}


/// Adds pattern-matching-related methods to [TransactionPage].
extension TransactionPagePatterns on TransactionPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionPage value)  $default,){
final _that = this;
switch (_that) {
case _TransactionPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionPage value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int count,  List<TransactionRecord> results)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionPage() when $default != null:
return $default(_that.count,_that.results);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int count,  List<TransactionRecord> results)  $default,) {final _that = this;
switch (_that) {
case _TransactionPage():
return $default(_that.count,_that.results);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int count,  List<TransactionRecord> results)?  $default,) {final _that = this;
switch (_that) {
case _TransactionPage() when $default != null:
return $default(_that.count,_that.results);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransactionPage implements TransactionPage {
  const _TransactionPage({required this.count,  List<TransactionRecord> results = const <TransactionRecord>[]}): _results = results;
  factory _TransactionPage.fromJson(Map<String, dynamic> json) => _$TransactionPageFromJson(json);

@override final  int count;
 final  List<TransactionRecord> _results;
@override@JsonKey() List<TransactionRecord> get results {
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_results);
}


/// Create a copy of TransactionPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionPageCopyWith<_TransactionPage> get copyWith => __$TransactionPageCopyWithImpl<_TransactionPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionPage&&(identical(other.count, count) || other.count == count)&&const DeepCollectionEquality().equals(other.results, _results));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,count,const DeepCollectionEquality().hash(_results));
}

@override
String toString() {
    return 'TransactionPage(count: $count, results: $results)';
}


}

/// @nodoc
abstract mixin class _$TransactionPageCopyWith<$Res> implements $TransactionPageCopyWith<$Res> {
  factory _$TransactionPageCopyWith(_TransactionPage value, $Res Function(_TransactionPage) _then) = __$TransactionPageCopyWithImpl;
@override @useResult
$Res call({
 int count, List<TransactionRecord> results
});




}
/// @nodoc
class __$TransactionPageCopyWithImpl<$Res>
    implements _$TransactionPageCopyWith<$Res> {
  __$TransactionPageCopyWithImpl(this._self, this._then);

  final _TransactionPage _self;
  final $Res Function(_TransactionPage) _then;

/// Create a copy of TransactionPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? count = null,Object? results = null,}) {
  return _then(_TransactionPage(
count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,results: null == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<TransactionRecord>,
  ));
}


}


/// @nodoc
mixin _$TransactionCategory {

 int get id; String get name;
/// Create a copy of TransactionCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionCategoryCopyWith<TransactionCategory> get copyWith => _$TransactionCategoryCopyWithImpl<TransactionCategory>(this as TransactionCategory, _$identity);

  /// Serializes this TransactionCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TransactionCategory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionCategory&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TransactionCategory;
  return Object.hash(runtimeType,_this.id,_this.name);
}

@override
String toString() {
  final _this = this as TransactionCategory;
  return 'TransactionCategory(id: ${_this.id}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $TransactionCategoryCopyWith<$Res>  {
  factory $TransactionCategoryCopyWith(TransactionCategory value, $Res Function(TransactionCategory) _then) = _$TransactionCategoryCopyWithImpl;
@useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class _$TransactionCategoryCopyWithImpl<$Res>
    implements $TransactionCategoryCopyWith<$Res> {
  _$TransactionCategoryCopyWithImpl(this._self, this._then);

  final TransactionCategory _self;
  final $Res Function(TransactionCategory) _then;

/// Create a copy of TransactionCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(TransactionCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TransactionCategory].
extension TransactionCategoryPatterns on TransactionCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionCategory value)  $default,){
final _that = this;
switch (_that) {
case _TransactionCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionCategory value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionCategory() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name)  $default,) {final _that = this;
switch (_that) {
case _TransactionCategory():
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _TransactionCategory() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransactionCategory implements TransactionCategory {
  const _TransactionCategory({required this.id, required this.name});
  factory _TransactionCategory.fromJson(Map<String, dynamic> json) => _$TransactionCategoryFromJson(json);

@override final  int id;
@override final  String name;

/// Create a copy of TransactionCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionCategoryCopyWith<_TransactionCategory> get copyWith => __$TransactionCategoryCopyWithImpl<_TransactionCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name);
}

@override
String toString() {
    return 'TransactionCategory(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$TransactionCategoryCopyWith<$Res> implements $TransactionCategoryCopyWith<$Res> {
  factory _$TransactionCategoryCopyWith(_TransactionCategory value, $Res Function(_TransactionCategory) _then) = __$TransactionCategoryCopyWithImpl;
@override @useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class __$TransactionCategoryCopyWithImpl<$Res>
    implements _$TransactionCategoryCopyWith<$Res> {
  __$TransactionCategoryCopyWithImpl(this._self, this._then);

  final _TransactionCategory _self;
  final $Res Function(_TransactionCategory) _then;

/// Create a copy of TransactionCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_TransactionCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CategoryRule {

 int get id;@JsonKey(name: 'match_text') String get matchText;/// Null for transfer rules (see [isTransfer]).
 int? get category;@JsonKey(name: 'category_name') String? get categoryName;/// Marks matches as transfers instead of assigning a category.
@JsonKey(name: 'is_transfer') bool get isTransfer;@JsonKey(name: 'spread_months') int get spreadMonths; int get position;@JsonKey(name: 'is_regex') bool get isRegex;/// 'any', 'payment' (amount < 0) or 'income' (amount > 0). Direction and
/// size are independent facts about a transaction, so they are separate
/// conditions — the bounds below carry no sign.
 String get direction;/// Bounds on the amount WITHOUT its sign, as decimal strings ("20.00"),
/// null for no bound.
@JsonKey(name: 'min_amount') String? get minAmount;@JsonKey(name: 'min_inclusive') bool get minInclusive;@JsonKey(name: 'max_amount') String? get maxAmount;@JsonKey(name: 'max_inclusive') bool get maxInclusive;
/// Create a copy of CategoryRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryRuleCopyWith<CategoryRule> get copyWith => _$CategoryRuleCopyWithImpl<CategoryRule>(this as CategoryRule, _$identity);

  /// Serializes this CategoryRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CategoryRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryRule&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.matchText, _this.matchText) || other.matchText == _this.matchText)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.categoryName, _this.categoryName) || other.categoryName == _this.categoryName)&&(identical(other.isTransfer, _this.isTransfer) || other.isTransfer == _this.isTransfer)&&(identical(other.spreadMonths, _this.spreadMonths) || other.spreadMonths == _this.spreadMonths)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.isRegex, _this.isRegex) || other.isRegex == _this.isRegex)&&(identical(other.direction, _this.direction) || other.direction == _this.direction)&&(identical(other.minAmount, _this.minAmount) || other.minAmount == _this.minAmount)&&(identical(other.minInclusive, _this.minInclusive) || other.minInclusive == _this.minInclusive)&&(identical(other.maxAmount, _this.maxAmount) || other.maxAmount == _this.maxAmount)&&(identical(other.maxInclusive, _this.maxInclusive) || other.maxInclusive == _this.maxInclusive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CategoryRule;
  return Object.hash(runtimeType,_this.id,_this.matchText,_this.category,_this.categoryName,_this.isTransfer,_this.spreadMonths,_this.position,_this.isRegex,_this.direction,_this.minAmount,_this.minInclusive,_this.maxAmount,_this.maxInclusive);
}

@override
String toString() {
  final _this = this as CategoryRule;
  return 'CategoryRule(id: ${_this.id}, matchText: ${_this.matchText}, category: ${_this.category}, categoryName: ${_this.categoryName}, isTransfer: ${_this.isTransfer}, spreadMonths: ${_this.spreadMonths}, position: ${_this.position}, isRegex: ${_this.isRegex}, direction: ${_this.direction}, minAmount: ${_this.minAmount}, minInclusive: ${_this.minInclusive}, maxAmount: ${_this.maxAmount}, maxInclusive: ${_this.maxInclusive})';
}


}

/// @nodoc
abstract mixin class $CategoryRuleCopyWith<$Res>  {
  factory $CategoryRuleCopyWith(CategoryRule value, $Res Function(CategoryRule) _then) = _$CategoryRuleCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'match_text') String matchText, int? category,@JsonKey(name: 'category_name') String? categoryName,@JsonKey(name: 'is_transfer') bool isTransfer,@JsonKey(name: 'spread_months') int spreadMonths, int position,@JsonKey(name: 'is_regex') bool isRegex, String direction,@JsonKey(name: 'min_amount') String? minAmount,@JsonKey(name: 'min_inclusive') bool minInclusive,@JsonKey(name: 'max_amount') String? maxAmount,@JsonKey(name: 'max_inclusive') bool maxInclusive
});




}
/// @nodoc
class _$CategoryRuleCopyWithImpl<$Res>
    implements $CategoryRuleCopyWith<$Res> {
  _$CategoryRuleCopyWithImpl(this._self, this._then);

  final CategoryRule _self;
  final $Res Function(CategoryRule) _then;

/// Create a copy of CategoryRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? matchText = null,Object? category = freezed,Object? categoryName = freezed,Object? isTransfer = null,Object? spreadMonths = null,Object? position = null,Object? isRegex = null,Object? direction = null,Object? minAmount = freezed,Object? minInclusive = null,Object? maxAmount = freezed,Object? maxInclusive = null,}) {
  return _then(CategoryRule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,matchText: null == matchText ? _self.matchText : matchText // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,isTransfer: null == isTransfer ? _self.isTransfer : isTransfer // ignore: cast_nullable_to_non_nullable
as bool,spreadMonths: null == spreadMonths ? _self.spreadMonths : spreadMonths // ignore: cast_nullable_to_non_nullable
as int,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,isRegex: null == isRegex ? _self.isRegex : isRegex // ignore: cast_nullable_to_non_nullable
as bool,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,minAmount: freezed == minAmount ? _self.minAmount : minAmount // ignore: cast_nullable_to_non_nullable
as String?,minInclusive: null == minInclusive ? _self.minInclusive : minInclusive // ignore: cast_nullable_to_non_nullable
as bool,maxAmount: freezed == maxAmount ? _self.maxAmount : maxAmount // ignore: cast_nullable_to_non_nullable
as String?,maxInclusive: null == maxInclusive ? _self.maxInclusive : maxInclusive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CategoryRule].
extension CategoryRulePatterns on CategoryRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoryRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoryRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoryRule value)  $default,){
final _that = this;
switch (_that) {
case _CategoryRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoryRule value)?  $default,){
final _that = this;
switch (_that) {
case _CategoryRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'match_text')  String matchText,  int? category, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'spread_months')  int spreadMonths,  int position, @JsonKey(name: 'is_regex')  bool isRegex,  String direction, @JsonKey(name: 'min_amount')  String? minAmount, @JsonKey(name: 'min_inclusive')  bool minInclusive, @JsonKey(name: 'max_amount')  String? maxAmount, @JsonKey(name: 'max_inclusive')  bool maxInclusive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoryRule() when $default != null:
return $default(_that.id,_that.matchText,_that.category,_that.categoryName,_that.isTransfer,_that.spreadMonths,_that.position,_that.isRegex,_that.direction,_that.minAmount,_that.minInclusive,_that.maxAmount,_that.maxInclusive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'match_text')  String matchText,  int? category, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'spread_months')  int spreadMonths,  int position, @JsonKey(name: 'is_regex')  bool isRegex,  String direction, @JsonKey(name: 'min_amount')  String? minAmount, @JsonKey(name: 'min_inclusive')  bool minInclusive, @JsonKey(name: 'max_amount')  String? maxAmount, @JsonKey(name: 'max_inclusive')  bool maxInclusive)  $default,) {final _that = this;
switch (_that) {
case _CategoryRule():
return $default(_that.id,_that.matchText,_that.category,_that.categoryName,_that.isTransfer,_that.spreadMonths,_that.position,_that.isRegex,_that.direction,_that.minAmount,_that.minInclusive,_that.maxAmount,_that.maxInclusive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'match_text')  String matchText,  int? category, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'is_transfer')  bool isTransfer, @JsonKey(name: 'spread_months')  int spreadMonths,  int position, @JsonKey(name: 'is_regex')  bool isRegex,  String direction, @JsonKey(name: 'min_amount')  String? minAmount, @JsonKey(name: 'min_inclusive')  bool minInclusive, @JsonKey(name: 'max_amount')  String? maxAmount, @JsonKey(name: 'max_inclusive')  bool maxInclusive)?  $default,) {final _that = this;
switch (_that) {
case _CategoryRule() when $default != null:
return $default(_that.id,_that.matchText,_that.category,_that.categoryName,_that.isTransfer,_that.spreadMonths,_that.position,_that.isRegex,_that.direction,_that.minAmount,_that.minInclusive,_that.maxAmount,_that.maxInclusive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CategoryRule implements CategoryRule {
  const _CategoryRule({required this.id, @JsonKey(name: 'match_text') required this.matchText, this.category, @JsonKey(name: 'category_name') this.categoryName, @JsonKey(name: 'is_transfer') this.isTransfer = false, @JsonKey(name: 'spread_months') this.spreadMonths = 1, this.position = 0, @JsonKey(name: 'is_regex') this.isRegex = false, this.direction = 'any', @JsonKey(name: 'min_amount') this.minAmount, @JsonKey(name: 'min_inclusive') this.minInclusive = true, @JsonKey(name: 'max_amount') this.maxAmount, @JsonKey(name: 'max_inclusive') this.maxInclusive = false});
  factory _CategoryRule.fromJson(Map<String, dynamic> json) => _$CategoryRuleFromJson(json);

@override final  int id;
@override@JsonKey(name: 'match_text') final  String matchText;
/// Null for transfer rules (see [isTransfer]).
@override final  int? category;
@override@JsonKey(name: 'category_name') final  String? categoryName;
/// Marks matches as transfers instead of assigning a category.
@override@JsonKey(name: 'is_transfer') final  bool isTransfer;
@override@JsonKey(name: 'spread_months') final  int spreadMonths;
@override@JsonKey() final  int position;
@override@JsonKey(name: 'is_regex') final  bool isRegex;
/// 'any', 'payment' (amount < 0) or 'income' (amount > 0). Direction and
/// size are independent facts about a transaction, so they are separate
/// conditions — the bounds below carry no sign.
@override@JsonKey() final  String direction;
/// Bounds on the amount WITHOUT its sign, as decimal strings ("20.00"),
/// null for no bound.
@override@JsonKey(name: 'min_amount') final  String? minAmount;
@override@JsonKey(name: 'min_inclusive') final  bool minInclusive;
@override@JsonKey(name: 'max_amount') final  String? maxAmount;
@override@JsonKey(name: 'max_inclusive') final  bool maxInclusive;

/// Create a copy of CategoryRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryRuleCopyWith<_CategoryRule> get copyWith => __$CategoryRuleCopyWithImpl<_CategoryRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CategoryRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoryRule&&(identical(other.id, id) || other.id == id)&&(identical(other.matchText, matchText) || other.matchText == matchText)&&(identical(other.category, category) || other.category == category)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.isTransfer, isTransfer) || other.isTransfer == isTransfer)&&(identical(other.spreadMonths, spreadMonths) || other.spreadMonths == spreadMonths)&&(identical(other.position, position) || other.position == position)&&(identical(other.isRegex, isRegex) || other.isRegex == isRegex)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.minAmount, minAmount) || other.minAmount == minAmount)&&(identical(other.minInclusive, minInclusive) || other.minInclusive == minInclusive)&&(identical(other.maxAmount, maxAmount) || other.maxAmount == maxAmount)&&(identical(other.maxInclusive, maxInclusive) || other.maxInclusive == maxInclusive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,matchText,category,categoryName,isTransfer,spreadMonths,position,isRegex,direction,minAmount,minInclusive,maxAmount,maxInclusive);
}

@override
String toString() {
    return 'CategoryRule(id: $id, matchText: $matchText, category: $category, categoryName: $categoryName, isTransfer: $isTransfer, spreadMonths: $spreadMonths, position: $position, isRegex: $isRegex, direction: $direction, minAmount: $minAmount, minInclusive: $minInclusive, maxAmount: $maxAmount, maxInclusive: $maxInclusive)';
}


}

/// @nodoc
abstract mixin class _$CategoryRuleCopyWith<$Res> implements $CategoryRuleCopyWith<$Res> {
  factory _$CategoryRuleCopyWith(_CategoryRule value, $Res Function(_CategoryRule) _then) = __$CategoryRuleCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'match_text') String matchText, int? category,@JsonKey(name: 'category_name') String? categoryName,@JsonKey(name: 'is_transfer') bool isTransfer,@JsonKey(name: 'spread_months') int spreadMonths, int position,@JsonKey(name: 'is_regex') bool isRegex, String direction,@JsonKey(name: 'min_amount') String? minAmount,@JsonKey(name: 'min_inclusive') bool minInclusive,@JsonKey(name: 'max_amount') String? maxAmount,@JsonKey(name: 'max_inclusive') bool maxInclusive
});




}
/// @nodoc
class __$CategoryRuleCopyWithImpl<$Res>
    implements _$CategoryRuleCopyWith<$Res> {
  __$CategoryRuleCopyWithImpl(this._self, this._then);

  final _CategoryRule _self;
  final $Res Function(_CategoryRule) _then;

/// Create a copy of CategoryRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? matchText = null,Object? category = freezed,Object? categoryName = freezed,Object? isTransfer = null,Object? spreadMonths = null,Object? position = null,Object? isRegex = null,Object? direction = null,Object? minAmount = freezed,Object? minInclusive = null,Object? maxAmount = freezed,Object? maxInclusive = null,}) {
  return _then(_CategoryRule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,matchText: null == matchText ? _self.matchText : matchText // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,isTransfer: null == isTransfer ? _self.isTransfer : isTransfer // ignore: cast_nullable_to_non_nullable
as bool,spreadMonths: null == spreadMonths ? _self.spreadMonths : spreadMonths // ignore: cast_nullable_to_non_nullable
as int,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,isRegex: null == isRegex ? _self.isRegex : isRegex // ignore: cast_nullable_to_non_nullable
as bool,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,minAmount: freezed == minAmount ? _self.minAmount : minAmount // ignore: cast_nullable_to_non_nullable
as String?,minInclusive: null == minInclusive ? _self.minInclusive : minInclusive // ignore: cast_nullable_to_non_nullable
as bool,maxAmount: freezed == maxAmount ? _self.maxAmount : maxAmount // ignore: cast_nullable_to_non_nullable
as String?,maxInclusive: null == maxInclusive ? _self.maxInclusive : maxInclusive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$RulePreview {

 int get matched;@JsonKey(name: 'will_classify') int get willClassify; int get shadowed;@JsonKey(name: 'already_classified') int get alreadyClassified; List<RuleExample> get examples;
/// Create a copy of RulePreview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RulePreviewCopyWith<RulePreview> get copyWith => _$RulePreviewCopyWithImpl<RulePreview>(this as RulePreview, _$identity);

  /// Serializes this RulePreview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RulePreview;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RulePreview&&(identical(other.matched, _this.matched) || other.matched == _this.matched)&&(identical(other.willClassify, _this.willClassify) || other.willClassify == _this.willClassify)&&(identical(other.shadowed, _this.shadowed) || other.shadowed == _this.shadowed)&&(identical(other.alreadyClassified, _this.alreadyClassified) || other.alreadyClassified == _this.alreadyClassified)&&const DeepCollectionEquality().equals(other.examples, _this.examples));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RulePreview;
  return Object.hash(runtimeType,_this.matched,_this.willClassify,_this.shadowed,_this.alreadyClassified,const DeepCollectionEquality().hash(_this.examples));
}

@override
String toString() {
  final _this = this as RulePreview;
  return 'RulePreview(matched: ${_this.matched}, willClassify: ${_this.willClassify}, shadowed: ${_this.shadowed}, alreadyClassified: ${_this.alreadyClassified}, examples: ${_this.examples})';
}


}

/// @nodoc
abstract mixin class $RulePreviewCopyWith<$Res>  {
  factory $RulePreviewCopyWith(RulePreview value, $Res Function(RulePreview) _then) = _$RulePreviewCopyWithImpl;
@useResult
$Res call({
 int matched,@JsonKey(name: 'will_classify') int willClassify, int shadowed,@JsonKey(name: 'already_classified') int alreadyClassified, List<RuleExample> examples
});




}
/// @nodoc
class _$RulePreviewCopyWithImpl<$Res>
    implements $RulePreviewCopyWith<$Res> {
  _$RulePreviewCopyWithImpl(this._self, this._then);

  final RulePreview _self;
  final $Res Function(RulePreview) _then;

/// Create a copy of RulePreview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? matched = null,Object? willClassify = null,Object? shadowed = null,Object? alreadyClassified = null,Object? examples = null,}) {
  return _then(RulePreview(
matched: null == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as int,willClassify: null == willClassify ? _self.willClassify : willClassify // ignore: cast_nullable_to_non_nullable
as int,shadowed: null == shadowed ? _self.shadowed : shadowed // ignore: cast_nullable_to_non_nullable
as int,alreadyClassified: null == alreadyClassified ? _self.alreadyClassified : alreadyClassified // ignore: cast_nullable_to_non_nullable
as int,examples: null == examples ? _self.examples : examples // ignore: cast_nullable_to_non_nullable
as List<RuleExample>,
  ));
}

}


/// Adds pattern-matching-related methods to [RulePreview].
extension RulePreviewPatterns on RulePreview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RulePreview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RulePreview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RulePreview value)  $default,){
final _that = this;
switch (_that) {
case _RulePreview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RulePreview value)?  $default,){
final _that = this;
switch (_that) {
case _RulePreview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int matched, @JsonKey(name: 'will_classify')  int willClassify,  int shadowed, @JsonKey(name: 'already_classified')  int alreadyClassified,  List<RuleExample> examples)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RulePreview() when $default != null:
return $default(_that.matched,_that.willClassify,_that.shadowed,_that.alreadyClassified,_that.examples);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int matched, @JsonKey(name: 'will_classify')  int willClassify,  int shadowed, @JsonKey(name: 'already_classified')  int alreadyClassified,  List<RuleExample> examples)  $default,) {final _that = this;
switch (_that) {
case _RulePreview():
return $default(_that.matched,_that.willClassify,_that.shadowed,_that.alreadyClassified,_that.examples);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int matched, @JsonKey(name: 'will_classify')  int willClassify,  int shadowed, @JsonKey(name: 'already_classified')  int alreadyClassified,  List<RuleExample> examples)?  $default,) {final _that = this;
switch (_that) {
case _RulePreview() when $default != null:
return $default(_that.matched,_that.willClassify,_that.shadowed,_that.alreadyClassified,_that.examples);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RulePreview implements RulePreview {
  const _RulePreview({this.matched = 0, @JsonKey(name: 'will_classify') this.willClassify = 0, this.shadowed = 0, @JsonKey(name: 'already_classified') this.alreadyClassified = 0,  List<RuleExample> examples = const <RuleExample>[]}): _examples = examples;
  factory _RulePreview.fromJson(Map<String, dynamic> json) => _$RulePreviewFromJson(json);

@override@JsonKey() final  int matched;
@override@JsonKey(name: 'will_classify') final  int willClassify;
@override@JsonKey() final  int shadowed;
@override@JsonKey(name: 'already_classified') final  int alreadyClassified;
 final  List<RuleExample> _examples;
@override@JsonKey() List<RuleExample> get examples {
  if (_examples is EqualUnmodifiableListView) return _examples;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_examples);
}


/// Create a copy of RulePreview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RulePreviewCopyWith<_RulePreview> get copyWith => __$RulePreviewCopyWithImpl<_RulePreview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RulePreviewToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RulePreview&&(identical(other.matched, matched) || other.matched == matched)&&(identical(other.willClassify, willClassify) || other.willClassify == willClassify)&&(identical(other.shadowed, shadowed) || other.shadowed == shadowed)&&(identical(other.alreadyClassified, alreadyClassified) || other.alreadyClassified == alreadyClassified)&&const DeepCollectionEquality().equals(other.examples, _examples));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,matched,willClassify,shadowed,alreadyClassified,const DeepCollectionEquality().hash(_examples));
}

@override
String toString() {
    return 'RulePreview(matched: $matched, willClassify: $willClassify, shadowed: $shadowed, alreadyClassified: $alreadyClassified, examples: $examples)';
}


}

/// @nodoc
abstract mixin class _$RulePreviewCopyWith<$Res> implements $RulePreviewCopyWith<$Res> {
  factory _$RulePreviewCopyWith(_RulePreview value, $Res Function(_RulePreview) _then) = __$RulePreviewCopyWithImpl;
@override @useResult
$Res call({
 int matched,@JsonKey(name: 'will_classify') int willClassify, int shadowed,@JsonKey(name: 'already_classified') int alreadyClassified, List<RuleExample> examples
});




}
/// @nodoc
class __$RulePreviewCopyWithImpl<$Res>
    implements _$RulePreviewCopyWith<$Res> {
  __$RulePreviewCopyWithImpl(this._self, this._then);

  final _RulePreview _self;
  final $Res Function(_RulePreview) _then;

/// Create a copy of RulePreview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? matched = null,Object? willClassify = null,Object? shadowed = null,Object? alreadyClassified = null,Object? examples = null,}) {
  return _then(_RulePreview(
matched: null == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as int,willClassify: null == willClassify ? _self.willClassify : willClassify // ignore: cast_nullable_to_non_nullable
as int,shadowed: null == shadowed ? _self.shadowed : shadowed // ignore: cast_nullable_to_non_nullable
as int,alreadyClassified: null == alreadyClassified ? _self.alreadyClassified : alreadyClassified // ignore: cast_nullable_to_non_nullable
as int,examples: null == examples ? _self._examples : examples // ignore: cast_nullable_to_non_nullable
as List<RuleExample>,
  ));
}


}


/// @nodoc
mixin _$RuleExample {

@JsonKey(name: 'booking_date') String? get bookingDate; String get text;
/// Create a copy of RuleExample
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleExampleCopyWith<RuleExample> get copyWith => _$RuleExampleCopyWithImpl<RuleExample>(this as RuleExample, _$identity);

  /// Serializes this RuleExample to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RuleExample;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleExample&&(identical(other.bookingDate, _this.bookingDate) || other.bookingDate == _this.bookingDate)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RuleExample;
  return Object.hash(runtimeType,_this.bookingDate,_this.text);
}

@override
String toString() {
  final _this = this as RuleExample;
  return 'RuleExample(bookingDate: ${_this.bookingDate}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $RuleExampleCopyWith<$Res>  {
  factory $RuleExampleCopyWith(RuleExample value, $Res Function(RuleExample) _then) = _$RuleExampleCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'booking_date') String? bookingDate, String text
});




}
/// @nodoc
class _$RuleExampleCopyWithImpl<$Res>
    implements $RuleExampleCopyWith<$Res> {
  _$RuleExampleCopyWithImpl(this._self, this._then);

  final RuleExample _self;
  final $Res Function(RuleExample) _then;

/// Create a copy of RuleExample
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookingDate = freezed,Object? text = null,}) {
  return _then(RuleExample(
bookingDate: freezed == bookingDate ? _self.bookingDate : bookingDate // ignore: cast_nullable_to_non_nullable
as String?,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RuleExample].
extension RuleExamplePatterns on RuleExample {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleExample value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleExample() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleExample value)  $default,){
final _that = this;
switch (_that) {
case _RuleExample():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleExample value)?  $default,){
final _that = this;
switch (_that) {
case _RuleExample() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'booking_date')  String? bookingDate,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleExample() when $default != null:
return $default(_that.bookingDate,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'booking_date')  String? bookingDate,  String text)  $default,) {final _that = this;
switch (_that) {
case _RuleExample():
return $default(_that.bookingDate,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'booking_date')  String? bookingDate,  String text)?  $default,) {final _that = this;
switch (_that) {
case _RuleExample() when $default != null:
return $default(_that.bookingDate,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuleExample implements RuleExample {
  const _RuleExample({@JsonKey(name: 'booking_date') this.bookingDate, this.text = ''});
  factory _RuleExample.fromJson(Map<String, dynamic> json) => _$RuleExampleFromJson(json);

@override@JsonKey(name: 'booking_date') final  String? bookingDate;
@override@JsonKey() final  String text;

/// Create a copy of RuleExample
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleExampleCopyWith<_RuleExample> get copyWith => __$RuleExampleCopyWithImpl<_RuleExample>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleExampleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleExample&&(identical(other.bookingDate, bookingDate) || other.bookingDate == bookingDate)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bookingDate,text);
}

@override
String toString() {
    return 'RuleExample(bookingDate: $bookingDate, text: $text)';
}


}

/// @nodoc
abstract mixin class _$RuleExampleCopyWith<$Res> implements $RuleExampleCopyWith<$Res> {
  factory _$RuleExampleCopyWith(_RuleExample value, $Res Function(_RuleExample) _then) = __$RuleExampleCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'booking_date') String? bookingDate, String text
});




}
/// @nodoc
class __$RuleExampleCopyWithImpl<$Res>
    implements _$RuleExampleCopyWith<$Res> {
  __$RuleExampleCopyWithImpl(this._self, this._then);

  final _RuleExample _self;
  final $Res Function(_RuleExample) _then;

/// Create a copy of RuleExample
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookingDate = freezed,Object? text = null,}) {
  return _then(_RuleExample(
bookingDate: freezed == bookingDate ? _self.bookingDate : bookingDate // ignore: cast_nullable_to_non_nullable
as String?,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
