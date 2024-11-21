/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { relationalStore } from '@kit.ArkData';

export class AitDatabase {
  static _databaseName: string = "nim_kit_ait.db";
  static _databaseVersion = 1;
  static table: string = 'session_messages';
  static sessionIdColumn: string = 'session_id';
  static messageIdColumn: string = 'message_id';
  static myAccId: string = 'my_acc_id';
  private store: relationalStore.RdbStore | undefined = undefined;
  private static _instance: AitDatabase | undefined = undefined

  public static get instance() {
    return this._instance ?? (this._instance = new AitDatabase())
  }

  private constructor() {
  }

  static STORE_CONFIG: relationalStore.StoreConfig = {
    name: AitDatabase._databaseName, // 数据库文件名
    securityLevel: relationalStore.SecurityLevel.S3, // 数据库安全级别
    encrypt: false, // 可选参数，指定数据库是否加密，默认不加密。
    isReadOnly: false // 可选参数，指定数据库是否以只读方式打开。该参数默认为false，表示数据库可读可写。该参数为true时，只允许从数据库读取数据，不允许对数据库进行写操作，否则会返回错误码801。
  };
  static SQL_CREATE_TABLE = `CREATE TABLE IF NOT EXISTS ${AitDatabase.table}
  (ID INTEGER PRIMARY KEY AUTOINCREMENT,
  ${AitDatabase.sessionIdColumn} TEXT NOT NULL,
  ${AitDatabase.messageIdColumn} TEXT NOT NULL,
  ${AitDatabase.myAccId} TEXT NOT NULL)`

  /**
   * 获取数据库
   * @returns
   */
  async getDatabase(): Promise<relationalStore.RdbStore | undefined> {
    let store = await relationalStore.getRdbStore(getContext(), AitDatabase.STORE_CONFIG)
    if (store) {
      // 当数据库创建时，数据库默认版本为0
      if (store.version === 0) {
        store.executeSql(AitDatabase.SQL_CREATE_TABLE); // 创建数据表
        // 设置数据库的版本，入参为大于0的整数
        store.version = AitDatabase._databaseVersion;
      }
      return store
    }
    return undefined
  }

  /**
   * 插入一条@消息
   * @param sessionId
   * @param messageId
   * @param accId
   * @returns
   */
  async insertAitMessage(sessionId: string, messageId: string, accId: string): Promise<number | undefined> {
    if (!this.store) {
      this.store = await this.getDatabase()
    }
    const bucket: relationalStore.ValuesBucket = {
      'session_id': sessionId,
      'message_id': messageId,
      'my_acc_id': accId
    }
    return this.store?.insert(AitDatabase.table, bucket)
  }

  /**
   * 删除一条@消息
   * @param sessionId
   * @param messageId
   * @param accId
   * @returns
   */
  async deleteMessage(sessionId: string, messageId: string, accId: string): Promise<number | undefined> {
    if (!this.store) {
      this.store = await this.getDatabase()
    }
    let predicates1 = new relationalStore.RdbPredicates(`${AitDatabase.table}`);
    predicates1.equalTo(`${AitDatabase.sessionIdColumn}`, sessionId);
    predicates1.equalTo(`${AitDatabase.messageIdColumn}`, messageId);
    predicates1.equalTo(`${AitDatabase.myAccId}`, accId);
    return this.store?.delete(predicates1)
  }

  /**
   * 清除sessionId对应的所有messageId
   * @param sessionId
   * @param accId
   * @returns
   */
  async clearSessionAitMessage(sessionId: string, accId: string): Promise<number | undefined> {
    if (!this.store) {
      this.store = await this.getDatabase()
    }
    let predicates1 = new relationalStore.RdbPredicates(`${AitDatabase.table}`);
    predicates1.equalTo(`${AitDatabase.sessionIdColumn}`, sessionId);
    predicates1.equalTo(`${AitDatabase.myAccId}`, accId);
    return this.store?.delete(predicates1)
  }

  /**
   * 查询session中对应的@消息
   * @param sessionId
   * @param accId
   * @returns
   */
  async queryMessageIdsBySessionId(
    sessionId: string, accId: string): Promise<string[]> {
    if (!this.store) {
      this.store = await this.getDatabase()
    }
    let predicates1 = new relationalStore.RdbPredicates(AitDatabase.table);
    predicates1.equalTo(`${AitDatabase.sessionIdColumn}`, sessionId);
    predicates1.equalTo(`${AitDatabase.myAccId}`, accId);
    let resultSet = await this.store?.query(predicates1, [`${AitDatabase.messageIdColumn}`])
    let resultList: string[] = []
    if (resultSet) {
      while (resultSet.goToNextRow()) {
        resultList.push(...[resultSet.getString(resultSet.getColumnIndex(AitDatabase.messageIdColumn))])
      }
      resultSet.close()
    }
    return resultList

  }

  /**
   * 查询对应账号中所有@的sessionId
   * @param sessionId
   * @param accId
   * @returns
   */
  async queryAllAitSession(accId: string): Promise<string[]> {
    if (!this.store) {
      this.store = await this.getDatabase()
    }
    let predicates1 = new relationalStore.RdbPredicates(AitDatabase.table);
    predicates1.equalTo(AitDatabase.myAccId, accId);
    let resultSet = await this.store?.query(predicates1, [`${AitDatabase.sessionIdColumn}`])
    let resultList: string[] = []
    if (resultSet) {
      while (resultSet.goToNextRow()) {
        resultList.push(...[resultSet.getString(resultSet.getColumnIndex(AitDatabase.sessionIdColumn))])
      }
      resultSet.close()
    }
    return resultList

  }
}