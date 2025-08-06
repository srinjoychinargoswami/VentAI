// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_storage.dart';

// ignore_for_file: type=lint
class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userMessageMeta =
      const VerificationMeta('userMessage');
  @override
  late final GeneratedColumn<String> userMessage = GeneratedColumn<String>(
      'user_message', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aiResponseMeta =
      const VerificationMeta('aiResponse');
  @override
  late final GeneratedColumn<String> aiResponse = GeneratedColumn<String>(
      'ai_response', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emotionalStateMeta =
      const VerificationMeta('emotionalState');
  @override
  late final GeneratedColumn<String> emotionalState = GeneratedColumn<String>(
      'emotional_state', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isOfflineMeta =
      const VerificationMeta('isOffline');
  @override
  late final GeneratedColumn<bool> isOffline = GeneratedColumn<bool>(
      'is_offline', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_offline" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sentimentScoreMeta =
      const VerificationMeta('sentimentScore');
  @override
  late final GeneratedColumn<double> sentimentScore = GeneratedColumn<double>(
      'sentiment_score', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userMessage,
        aiResponse,
        emotionalState,
        timestamp,
        isOffline,
        sessionId,
        sentimentScore
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(Insertable<Conversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_message')) {
      context.handle(
          _userMessageMeta,
          userMessage.isAcceptableOrUnknown(
              data['user_message']!, _userMessageMeta));
    } else if (isInserting) {
      context.missing(_userMessageMeta);
    }
    if (data.containsKey('ai_response')) {
      context.handle(
          _aiResponseMeta,
          aiResponse.isAcceptableOrUnknown(
              data['ai_response']!, _aiResponseMeta));
    } else if (isInserting) {
      context.missing(_aiResponseMeta);
    }
    if (data.containsKey('emotional_state')) {
      context.handle(
          _emotionalStateMeta,
          emotionalState.isAcceptableOrUnknown(
              data['emotional_state']!, _emotionalStateMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_offline')) {
      context.handle(_isOfflineMeta,
          isOffline.isAcceptableOrUnknown(data['is_offline']!, _isOfflineMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('sentiment_score')) {
      context.handle(
          _sentimentScoreMeta,
          sentimentScore.isAcceptableOrUnknown(
              data['sentiment_score']!, _sentimentScoreMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_message'])!,
      aiResponse: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ai_response'])!,
      emotionalState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}emotional_state']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      isOffline: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_offline'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id']),
      sentimentScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}sentiment_score']),
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final int id;
  final String userMessage;
  final String aiResponse;
  final String? emotionalState;
  final DateTime timestamp;
  final bool isOffline;
  final String? sessionId;
  final double? sentimentScore;
  const Conversation(
      {required this.id,
      required this.userMessage,
      required this.aiResponse,
      this.emotionalState,
      required this.timestamp,
      required this.isOffline,
      this.sessionId,
      this.sentimentScore});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_message'] = Variable<String>(userMessage);
    map['ai_response'] = Variable<String>(aiResponse);
    if (!nullToAbsent || emotionalState != null) {
      map['emotional_state'] = Variable<String>(emotionalState);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['is_offline'] = Variable<bool>(isOffline);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || sentimentScore != null) {
      map['sentiment_score'] = Variable<double>(sentimentScore);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      userMessage: Value(userMessage),
      aiResponse: Value(aiResponse),
      emotionalState: emotionalState == null && nullToAbsent
          ? const Value.absent()
          : Value(emotionalState),
      timestamp: Value(timestamp),
      isOffline: Value(isOffline),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      sentimentScore: sentimentScore == null && nullToAbsent
          ? const Value.absent()
          : Value(sentimentScore),
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<int>(json['id']),
      userMessage: serializer.fromJson<String>(json['userMessage']),
      aiResponse: serializer.fromJson<String>(json['aiResponse']),
      emotionalState: serializer.fromJson<String?>(json['emotionalState']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      isOffline: serializer.fromJson<bool>(json['isOffline']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      sentimentScore: serializer.fromJson<double?>(json['sentimentScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userMessage': serializer.toJson<String>(userMessage),
      'aiResponse': serializer.toJson<String>(aiResponse),
      'emotionalState': serializer.toJson<String?>(emotionalState),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'isOffline': serializer.toJson<bool>(isOffline),
      'sessionId': serializer.toJson<String?>(sessionId),
      'sentimentScore': serializer.toJson<double?>(sentimentScore),
    };
  }

  Conversation copyWith(
          {int? id,
          String? userMessage,
          String? aiResponse,
          Value<String?> emotionalState = const Value.absent(),
          DateTime? timestamp,
          bool? isOffline,
          Value<String?> sessionId = const Value.absent(),
          Value<double?> sentimentScore = const Value.absent()}) =>
      Conversation(
        id: id ?? this.id,
        userMessage: userMessage ?? this.userMessage,
        aiResponse: aiResponse ?? this.aiResponse,
        emotionalState:
            emotionalState.present ? emotionalState.value : this.emotionalState,
        timestamp: timestamp ?? this.timestamp,
        isOffline: isOffline ?? this.isOffline,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        sentimentScore:
            sentimentScore.present ? sentimentScore.value : this.sentimentScore,
      );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      userMessage:
          data.userMessage.present ? data.userMessage.value : this.userMessage,
      aiResponse:
          data.aiResponse.present ? data.aiResponse.value : this.aiResponse,
      emotionalState: data.emotionalState.present
          ? data.emotionalState.value
          : this.emotionalState,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isOffline: data.isOffline.present ? data.isOffline.value : this.isOffline,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sentimentScore: data.sentimentScore.present
          ? data.sentimentScore.value
          : this.sentimentScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('userMessage: $userMessage, ')
          ..write('aiResponse: $aiResponse, ')
          ..write('emotionalState: $emotionalState, ')
          ..write('timestamp: $timestamp, ')
          ..write('isOffline: $isOffline, ')
          ..write('sessionId: $sessionId, ')
          ..write('sentimentScore: $sentimentScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userMessage, aiResponse, emotionalState,
      timestamp, isOffline, sessionId, sentimentScore);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.userMessage == this.userMessage &&
          other.aiResponse == this.aiResponse &&
          other.emotionalState == this.emotionalState &&
          other.timestamp == this.timestamp &&
          other.isOffline == this.isOffline &&
          other.sessionId == this.sessionId &&
          other.sentimentScore == this.sentimentScore);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<int> id;
  final Value<String> userMessage;
  final Value<String> aiResponse;
  final Value<String?> emotionalState;
  final Value<DateTime> timestamp;
  final Value<bool> isOffline;
  final Value<String?> sessionId;
  final Value<double?> sentimentScore;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.userMessage = const Value.absent(),
    this.aiResponse = const Value.absent(),
    this.emotionalState = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isOffline = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.sentimentScore = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.id = const Value.absent(),
    required String userMessage,
    required String aiResponse,
    this.emotionalState = const Value.absent(),
    required DateTime timestamp,
    this.isOffline = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.sentimentScore = const Value.absent(),
  })  : userMessage = Value(userMessage),
        aiResponse = Value(aiResponse),
        timestamp = Value(timestamp);
  static Insertable<Conversation> custom({
    Expression<int>? id,
    Expression<String>? userMessage,
    Expression<String>? aiResponse,
    Expression<String>? emotionalState,
    Expression<DateTime>? timestamp,
    Expression<bool>? isOffline,
    Expression<String>? sessionId,
    Expression<double>? sentimentScore,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userMessage != null) 'user_message': userMessage,
      if (aiResponse != null) 'ai_response': aiResponse,
      if (emotionalState != null) 'emotional_state': emotionalState,
      if (timestamp != null) 'timestamp': timestamp,
      if (isOffline != null) 'is_offline': isOffline,
      if (sessionId != null) 'session_id': sessionId,
      if (sentimentScore != null) 'sentiment_score': sentimentScore,
    });
  }

  ConversationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? userMessage,
      Value<String>? aiResponse,
      Value<String?>? emotionalState,
      Value<DateTime>? timestamp,
      Value<bool>? isOffline,
      Value<String?>? sessionId,
      Value<double?>? sentimentScore}) {
    return ConversationsCompanion(
      id: id ?? this.id,
      userMessage: userMessage ?? this.userMessage,
      aiResponse: aiResponse ?? this.aiResponse,
      emotionalState: emotionalState ?? this.emotionalState,
      timestamp: timestamp ?? this.timestamp,
      isOffline: isOffline ?? this.isOffline,
      sessionId: sessionId ?? this.sessionId,
      sentimentScore: sentimentScore ?? this.sentimentScore,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userMessage.present) {
      map['user_message'] = Variable<String>(userMessage.value);
    }
    if (aiResponse.present) {
      map['ai_response'] = Variable<String>(aiResponse.value);
    }
    if (emotionalState.present) {
      map['emotional_state'] = Variable<String>(emotionalState.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (isOffline.present) {
      map['is_offline'] = Variable<bool>(isOffline.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (sentimentScore.present) {
      map['sentiment_score'] = Variable<double>(sentimentScore.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('userMessage: $userMessage, ')
          ..write('aiResponse: $aiResponse, ')
          ..write('emotionalState: $emotionalState, ')
          ..write('timestamp: $timestamp, ')
          ..write('isOffline: $isOffline, ')
          ..write('sessionId: $sessionId, ')
          ..write('sentimentScore: $sentimentScore')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTable extends UserPreferences
    with TableInfo<$UserPreferencesTable, UserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _preferenceKeyMeta =
      const VerificationMeta('preferenceKey');
  @override
  late final GeneratedColumn<String> preferenceKey = GeneratedColumn<String>(
      'preference_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _preferenceValueMeta =
      const VerificationMeta('preferenceValue');
  @override
  late final GeneratedColumn<String> preferenceValue = GeneratedColumn<String>(
      'preference_value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, preferenceKey, preferenceValue, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(Insertable<UserPreference> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('preference_key')) {
      context.handle(
          _preferenceKeyMeta,
          preferenceKey.isAcceptableOrUnknown(
              data['preference_key']!, _preferenceKeyMeta));
    } else if (isInserting) {
      context.missing(_preferenceKeyMeta);
    }
    if (data.containsKey('preference_value')) {
      context.handle(
          _preferenceValueMeta,
          preferenceValue.isAcceptableOrUnknown(
              data['preference_value']!, _preferenceValueMeta));
    } else if (isInserting) {
      context.missing(_preferenceValueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreference(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      preferenceKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}preference_key'])!,
      preferenceValue: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preference_value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserPreferencesTable createAlias(String alias) {
    return $UserPreferencesTable(attachedDatabase, alias);
  }
}

class UserPreference extends DataClass implements Insertable<UserPreference> {
  final int id;
  final String preferenceKey;
  final String preferenceValue;
  final DateTime updatedAt;
  const UserPreference(
      {required this.id,
      required this.preferenceKey,
      required this.preferenceValue,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['preference_key'] = Variable<String>(preferenceKey);
    map['preference_value'] = Variable<String>(preferenceValue);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
      id: Value(id),
      preferenceKey: Value(preferenceKey),
      preferenceValue: Value(preferenceValue),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserPreference.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreference(
      id: serializer.fromJson<int>(json['id']),
      preferenceKey: serializer.fromJson<String>(json['preferenceKey']),
      preferenceValue: serializer.fromJson<String>(json['preferenceValue']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'preferenceKey': serializer.toJson<String>(preferenceKey),
      'preferenceValue': serializer.toJson<String>(preferenceValue),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPreference copyWith(
          {int? id,
          String? preferenceKey,
          String? preferenceValue,
          DateTime? updatedAt}) =>
      UserPreference(
        id: id ?? this.id,
        preferenceKey: preferenceKey ?? this.preferenceKey,
        preferenceValue: preferenceValue ?? this.preferenceValue,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserPreference copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreference(
      id: data.id.present ? data.id.value : this.id,
      preferenceKey: data.preferenceKey.present
          ? data.preferenceKey.value
          : this.preferenceKey,
      preferenceValue: data.preferenceValue.present
          ? data.preferenceValue.value
          : this.preferenceValue,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreference(')
          ..write('id: $id, ')
          ..write('preferenceKey: $preferenceKey, ')
          ..write('preferenceValue: $preferenceValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, preferenceKey, preferenceValue, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreference &&
          other.id == this.id &&
          other.preferenceKey == this.preferenceKey &&
          other.preferenceValue == this.preferenceValue &&
          other.updatedAt == this.updatedAt);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreference> {
  final Value<int> id;
  final Value<String> preferenceKey;
  final Value<String> preferenceValue;
  final Value<DateTime> updatedAt;
  const UserPreferencesCompanion({
    this.id = const Value.absent(),
    this.preferenceKey = const Value.absent(),
    this.preferenceValue = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    this.id = const Value.absent(),
    required String preferenceKey,
    required String preferenceValue,
    required DateTime updatedAt,
  })  : preferenceKey = Value(preferenceKey),
        preferenceValue = Value(preferenceValue),
        updatedAt = Value(updatedAt);
  static Insertable<UserPreference> custom({
    Expression<int>? id,
    Expression<String>? preferenceKey,
    Expression<String>? preferenceValue,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (preferenceKey != null) 'preference_key': preferenceKey,
      if (preferenceValue != null) 'preference_value': preferenceValue,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserPreferencesCompanion copyWith(
      {Value<int>? id,
      Value<String>? preferenceKey,
      Value<String>? preferenceValue,
      Value<DateTime>? updatedAt}) {
    return UserPreferencesCompanion(
      id: id ?? this.id,
      preferenceKey: preferenceKey ?? this.preferenceKey,
      preferenceValue: preferenceValue ?? this.preferenceValue,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (preferenceKey.present) {
      map['preference_key'] = Variable<String>(preferenceKey.value);
    }
    if (preferenceValue.present) {
      map['preference_value'] = Variable<String>(preferenceValue.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('preferenceKey: $preferenceKey, ')
          ..write('preferenceValue: $preferenceValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MoodEntriesTable extends MoodEntries
    with TableInfo<$MoodEntriesTable, MoodEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoodEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
      'mood', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _intensityMeta =
      const VerificationMeta('intensity');
  @override
  late final GeneratedColumn<double> intensity = GeneratedColumn<double>(
      'intensity', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, mood, intensity, notes, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mood_entries';
  @override
  VerificationContext validateIntegrity(Insertable<MoodEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mood')) {
      context.handle(
          _moodMeta, mood.isAcceptableOrUnknown(data['mood']!, _moodMeta));
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    if (data.containsKey('intensity')) {
      context.handle(_intensityMeta,
          intensity.isAcceptableOrUnknown(data['intensity']!, _intensityMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MoodEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoodEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mood: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mood'])!,
      intensity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}intensity']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $MoodEntriesTable createAlias(String alias) {
    return $MoodEntriesTable(attachedDatabase, alias);
  }
}

class MoodEntry extends DataClass implements Insertable<MoodEntry> {
  final int id;
  final String mood;
  final double? intensity;
  final String? notes;
  final DateTime timestamp;
  const MoodEntry(
      {required this.id,
      required this.mood,
      this.intensity,
      this.notes,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mood'] = Variable<String>(mood);
    if (!nullToAbsent || intensity != null) {
      map['intensity'] = Variable<double>(intensity);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  MoodEntriesCompanion toCompanion(bool nullToAbsent) {
    return MoodEntriesCompanion(
      id: Value(id),
      mood: Value(mood),
      intensity: intensity == null && nullToAbsent
          ? const Value.absent()
          : Value(intensity),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      timestamp: Value(timestamp),
    );
  }

  factory MoodEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoodEntry(
      id: serializer.fromJson<int>(json['id']),
      mood: serializer.fromJson<String>(json['mood']),
      intensity: serializer.fromJson<double?>(json['intensity']),
      notes: serializer.fromJson<String?>(json['notes']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mood': serializer.toJson<String>(mood),
      'intensity': serializer.toJson<double?>(intensity),
      'notes': serializer.toJson<String?>(notes),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  MoodEntry copyWith(
          {int? id,
          String? mood,
          Value<double?> intensity = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? timestamp}) =>
      MoodEntry(
        id: id ?? this.id,
        mood: mood ?? this.mood,
        intensity: intensity.present ? intensity.value : this.intensity,
        notes: notes.present ? notes.value : this.notes,
        timestamp: timestamp ?? this.timestamp,
      );
  MoodEntry copyWithCompanion(MoodEntriesCompanion data) {
    return MoodEntry(
      id: data.id.present ? data.id.value : this.id,
      mood: data.mood.present ? data.mood.value : this.mood,
      intensity: data.intensity.present ? data.intensity.value : this.intensity,
      notes: data.notes.present ? data.notes.value : this.notes,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoodEntry(')
          ..write('id: $id, ')
          ..write('mood: $mood, ')
          ..write('intensity: $intensity, ')
          ..write('notes: $notes, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mood, intensity, notes, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoodEntry &&
          other.id == this.id &&
          other.mood == this.mood &&
          other.intensity == this.intensity &&
          other.notes == this.notes &&
          other.timestamp == this.timestamp);
}

class MoodEntriesCompanion extends UpdateCompanion<MoodEntry> {
  final Value<int> id;
  final Value<String> mood;
  final Value<double?> intensity;
  final Value<String?> notes;
  final Value<DateTime> timestamp;
  const MoodEntriesCompanion({
    this.id = const Value.absent(),
    this.mood = const Value.absent(),
    this.intensity = const Value.absent(),
    this.notes = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  MoodEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String mood,
    this.intensity = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime timestamp,
  })  : mood = Value(mood),
        timestamp = Value(timestamp);
  static Insertable<MoodEntry> custom({
    Expression<int>? id,
    Expression<String>? mood,
    Expression<double>? intensity,
    Expression<String>? notes,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mood != null) 'mood': mood,
      if (intensity != null) 'intensity': intensity,
      if (notes != null) 'notes': notes,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  MoodEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? mood,
      Value<double?>? intensity,
      Value<String?>? notes,
      Value<DateTime>? timestamp}) {
    return MoodEntriesCompanion(
      id: id ?? this.id,
      mood: mood ?? this.mood,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (intensity.present) {
      map['intensity'] = Variable<double>(intensity.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoodEntriesCompanion(')
          ..write('id: $id, ')
          ..write('mood: $mood, ')
          ..write('intensity: $intensity, ')
          ..write('notes: $notes, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $UserPreferencesTable userPreferences =
      $UserPreferencesTable(this);
  late final $MoodEntriesTable moodEntries = $MoodEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [conversations, userPreferences, moodEntries];
}

typedef $$ConversationsTableCreateCompanionBuilder = ConversationsCompanion
    Function({
  Value<int> id,
  required String userMessage,
  required String aiResponse,
  Value<String?> emotionalState,
  required DateTime timestamp,
  Value<bool> isOffline,
  Value<String?> sessionId,
  Value<double?> sentimentScore,
});
typedef $$ConversationsTableUpdateCompanionBuilder = ConversationsCompanion
    Function({
  Value<int> id,
  Value<String> userMessage,
  Value<String> aiResponse,
  Value<String?> emotionalState,
  Value<DateTime> timestamp,
  Value<bool> isOffline,
  Value<String?> sessionId,
  Value<double?> sentimentScore,
});

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userMessage => $composableBuilder(
      column: $table.userMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aiResponse => $composableBuilder(
      column: $table.aiResponse, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get emotionalState => $composableBuilder(
      column: $table.emotionalState,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isOffline => $composableBuilder(
      column: $table.isOffline, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sentimentScore => $composableBuilder(
      column: $table.sentimentScore,
      builder: (column) => ColumnFilters(column));
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userMessage => $composableBuilder(
      column: $table.userMessage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aiResponse => $composableBuilder(
      column: $table.aiResponse, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get emotionalState => $composableBuilder(
      column: $table.emotionalState,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isOffline => $composableBuilder(
      column: $table.isOffline, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sentimentScore => $composableBuilder(
      column: $table.sentimentScore,
      builder: (column) => ColumnOrderings(column));
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userMessage => $composableBuilder(
      column: $table.userMessage, builder: (column) => column);

  GeneratedColumn<String> get aiResponse => $composableBuilder(
      column: $table.aiResponse, builder: (column) => column);

  GeneratedColumn<String> get emotionalState => $composableBuilder(
      column: $table.emotionalState, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isOffline =>
      $composableBuilder(column: $table.isOffline, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<double> get sentimentScore => $composableBuilder(
      column: $table.sentimentScore, builder: (column) => column);
}

class $$ConversationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()> {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userMessage = const Value.absent(),
            Value<String> aiResponse = const Value.absent(),
            Value<String?> emotionalState = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<bool> isOffline = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<double?> sentimentScore = const Value.absent(),
          }) =>
              ConversationsCompanion(
            id: id,
            userMessage: userMessage,
            aiResponse: aiResponse,
            emotionalState: emotionalState,
            timestamp: timestamp,
            isOffline: isOffline,
            sessionId: sessionId,
            sentimentScore: sentimentScore,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userMessage,
            required String aiResponse,
            Value<String?> emotionalState = const Value.absent(),
            required DateTime timestamp,
            Value<bool> isOffline = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<double?> sentimentScore = const Value.absent(),
          }) =>
              ConversationsCompanion.insert(
            id: id,
            userMessage: userMessage,
            aiResponse: aiResponse,
            emotionalState: emotionalState,
            timestamp: timestamp,
            isOffline: isOffline,
            sessionId: sessionId,
            sentimentScore: sentimentScore,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()>;
typedef $$UserPreferencesTableCreateCompanionBuilder = UserPreferencesCompanion
    Function({
  Value<int> id,
  required String preferenceKey,
  required String preferenceValue,
  required DateTime updatedAt,
});
typedef $$UserPreferencesTableUpdateCompanionBuilder = UserPreferencesCompanion
    Function({
  Value<int> id,
  Value<String> preferenceKey,
  Value<String> preferenceValue,
  Value<DateTime> updatedAt,
});

class $$UserPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferenceKey => $composableBuilder(
      column: $table.preferenceKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferenceValue => $composableBuilder(
      column: $table.preferenceValue,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$UserPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferenceKey => $composableBuilder(
      column: $table.preferenceKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferenceValue => $composableBuilder(
      column: $table.preferenceValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$UserPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get preferenceKey => $composableBuilder(
      column: $table.preferenceKey, builder: (column) => column);

  GeneratedColumn<String> get preferenceValue => $composableBuilder(
      column: $table.preferenceValue, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPreferencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserPreferencesTable,
    UserPreference,
    $$UserPreferencesTableFilterComposer,
    $$UserPreferencesTableOrderingComposer,
    $$UserPreferencesTableAnnotationComposer,
    $$UserPreferencesTableCreateCompanionBuilder,
    $$UserPreferencesTableUpdateCompanionBuilder,
    (
      UserPreference,
      BaseReferences<_$AppDatabase, $UserPreferencesTable, UserPreference>
    ),
    UserPreference,
    PrefetchHooks Function()> {
  $$UserPreferencesTableTableManager(
      _$AppDatabase db, $UserPreferencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> preferenceKey = const Value.absent(),
            Value<String> preferenceValue = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              UserPreferencesCompanion(
            id: id,
            preferenceKey: preferenceKey,
            preferenceValue: preferenceValue,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String preferenceKey,
            required String preferenceValue,
            required DateTime updatedAt,
          }) =>
              UserPreferencesCompanion.insert(
            id: id,
            preferenceKey: preferenceKey,
            preferenceValue: preferenceValue,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserPreferencesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserPreferencesTable,
    UserPreference,
    $$UserPreferencesTableFilterComposer,
    $$UserPreferencesTableOrderingComposer,
    $$UserPreferencesTableAnnotationComposer,
    $$UserPreferencesTableCreateCompanionBuilder,
    $$UserPreferencesTableUpdateCompanionBuilder,
    (
      UserPreference,
      BaseReferences<_$AppDatabase, $UserPreferencesTable, UserPreference>
    ),
    UserPreference,
    PrefetchHooks Function()>;
typedef $$MoodEntriesTableCreateCompanionBuilder = MoodEntriesCompanion
    Function({
  Value<int> id,
  required String mood,
  Value<double?> intensity,
  Value<String?> notes,
  required DateTime timestamp,
});
typedef $$MoodEntriesTableUpdateCompanionBuilder = MoodEntriesCompanion
    Function({
  Value<int> id,
  Value<String> mood,
  Value<double?> intensity,
  Value<String?> notes,
  Value<DateTime> timestamp,
});

class $$MoodEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MoodEntriesTable> {
  $$MoodEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mood => $composableBuilder(
      column: $table.mood, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get intensity => $composableBuilder(
      column: $table.intensity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$MoodEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MoodEntriesTable> {
  $$MoodEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mood => $composableBuilder(
      column: $table.mood, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get intensity => $composableBuilder(
      column: $table.intensity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$MoodEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoodEntriesTable> {
  $$MoodEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<double> get intensity =>
      $composableBuilder(column: $table.intensity, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$MoodEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MoodEntriesTable,
    MoodEntry,
    $$MoodEntriesTableFilterComposer,
    $$MoodEntriesTableOrderingComposer,
    $$MoodEntriesTableAnnotationComposer,
    $$MoodEntriesTableCreateCompanionBuilder,
    $$MoodEntriesTableUpdateCompanionBuilder,
    (MoodEntry, BaseReferences<_$AppDatabase, $MoodEntriesTable, MoodEntry>),
    MoodEntry,
    PrefetchHooks Function()> {
  $$MoodEntriesTableTableManager(_$AppDatabase db, $MoodEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoodEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoodEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoodEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> mood = const Value.absent(),
            Value<double?> intensity = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              MoodEntriesCompanion(
            id: id,
            mood: mood,
            intensity: intensity,
            notes: notes,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String mood,
            Value<double?> intensity = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required DateTime timestamp,
          }) =>
              MoodEntriesCompanion.insert(
            id: id,
            mood: mood,
            intensity: intensity,
            notes: notes,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MoodEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MoodEntriesTable,
    MoodEntry,
    $$MoodEntriesTableFilterComposer,
    $$MoodEntriesTableOrderingComposer,
    $$MoodEntriesTableAnnotationComposer,
    $$MoodEntriesTableCreateCompanionBuilder,
    $$MoodEntriesTableUpdateCompanionBuilder,
    (MoodEntry, BaseReferences<_$AppDatabase, $MoodEntriesTable, MoodEntry>),
    MoodEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
  $$MoodEntriesTableTableManager get moodEntries =>
      $$MoodEntriesTableTableManager(_db, _db.moodEntries);
}
