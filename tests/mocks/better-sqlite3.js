export class MockStatement {
  constructor(sql, db) {
    this.sql = sql;
    this.db = db;
    this.bindValues = [];
  }

  run(...params) {
    this.bindValues = params;
    
    if (this.db.shouldFail) {
      throw new Error('Database operation failed');
    }

    this.db.lastStatement = this;
    
    return {
      changes: 1,
      lastInsertRowid: this.db.nextRowId++
    };
  }

  get(...params) {
    this.bindValues = params;
    
    if (this.db.shouldFail) {
      throw new Error('Database operation failed');
    }

    this.db.lastStatement = this;
    
    const result = this.db.queryResults.get(this.sql);
    return result ? result[0] : undefined;
  }

  all(...params) {
    this.bindValues = params;
    
    if (this.db.shouldFail) {
      throw new Error('Database operation failed');
    }

    this.db.lastStatement = this;
    
    const result = this.db.queryResults.get(this.sql);
    return result || [];
  }

  pluck(toggle = true) {
    this.pluckMode = toggle;
    return this;
  }

  expand(toggle = true) {
    this.expandMode = toggle;
    return this;
  }
}

export class MockDatabase {
  constructor(filename, options = {}) {
    this.filename = filename;
    this.options = options;
    this.isOpen = true;
    this.shouldFail = options.shouldFail || false;
    this.queryResults = new Map();
    this.statements = [];
    this.lastStatement = null;
    this.nextRowId = 1;
    this.pragmaValues = new Map();
    this.inTransaction = false;
  }

  prepare(sql) {
    if (!this.isOpen) {
      throw new Error('Database is closed');
    }
    
    if (this.shouldFail) {
      throw new Error('Failed to prepare statement');
    }

    const statement = new MockStatement(sql, this);
    this.statements.push(statement);
    return statement;
  }

  exec(sql) {
    if (!this.isOpen) {
      throw new Error('Database is closed');
    }
    
    if (this.shouldFail) {
      throw new Error('Failed to execute SQL');
    }

    if (sql.includes('BEGIN')) {
      this.inTransaction = true;
    } else if (sql.includes('COMMIT') || sql.includes('ROLLBACK')) {
      this.inTransaction = false;
    }

    return this;
  }

  pragma(pragma, options) {
    if (!this.isOpen) {
      throw new Error('Database is closed');
    }

    if (options !== undefined) {
      this.pragmaValues.set(pragma, options);
      return this;
    }

    return this.pragmaValues.get(pragma);
  }

  close() {
    this.isOpen = false;
  }

  transaction(fn) {
    return (...args) => {
      this.inTransaction = true;
      try {
        const result = fn(...args);
        this.inTransaction = false;
        return result;
      } catch (error) {
        this.inTransaction = false;
        throw error;
      }
    };
  }

  setQueryResult(sql, rows) {
    this.queryResults.set(sql, rows);
  }
}

export default MockDatabase;
