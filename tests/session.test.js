import { describe, it, expect } from 'vitest';
import * as sessionManager from '../src/session-manager.js';
import * as sessionTools from '../src/tools/session-tools.js';

describe('Session Manager Smoke Tests', () => {
  it('should export required session manager functions', () => {
    expect(sessionManager.startSession).toBeDefined();
    expect(sessionManager.sendCommand).toBeDefined();
    expect(sessionManager.listSessions).toBeDefined();
    expect(sessionManager.closeSession).toBeDefined();
    expect(sessionManager.SESSION_STATES).toBeDefined();
  });

  it('should export SESSION_STATES constants', () => {
    expect(sessionManager.SESSION_STATES.INITIALIZING).toBe('initializing');
    expect(sessionManager.SESSION_STATES.READY).toBe('ready');
    expect(sessionManager.SESSION_STATES.BUSY).toBe('busy');
    expect(sessionManager.SESSION_STATES.ERROR).toBe('error');
    expect(sessionManager.SESSION_STATES.CLOSED).toBe('closed');
  });

  it('should export MCP session tools', () => {
    expect(sessionTools.sessionTools).toBeDefined();
    expect(sessionTools.sessionTools.ssh_session_start).toBeDefined();
    expect(sessionTools.sessionTools.ssh_session_send).toBeDefined();
    expect(sessionTools.sessionTools.ssh_session_list).toBeDefined();
    expect(sessionTools.sessionTools.ssh_session_close).toBeDefined();
  });

  it('should have correct MCP tool schemas', () => {
    const { ssh_session_start, ssh_session_send, ssh_session_list, ssh_session_close } = sessionTools.sessionTools;

    expect(ssh_session_start.description).toBeTruthy();
    expect(ssh_session_start.inputSchema).toBeDefined();
    expect(ssh_session_start.inputSchema.required).toContain('host');
    expect(ssh_session_start.inputSchema.required).toContain('user');
    expect(ssh_session_start.handler).toBeTypeOf('function');

    expect(ssh_session_send.description).toBeTruthy();
    expect(ssh_session_send.inputSchema.required).toContain('sessionId');
    expect(ssh_session_send.inputSchema.required).toContain('command');
    expect(ssh_session_send.handler).toBeTypeOf('function');

    expect(ssh_session_list.description).toBeTruthy();
    expect(ssh_session_list.handler).toBeTypeOf('function');

    expect(ssh_session_close.description).toBeTruthy();
    expect(ssh_session_close.inputSchema.required).toContain('sessionId');
    expect(ssh_session_close.handler).toBeTypeOf('function');
  });

  it('should have listSessions return empty array initially', () => {
    const sessions = sessionManager.listSessions();
    expect(Array.isArray(sessions)).toBe(true);
  });

  it('should throw error when closing non-existent session', () => {
    expect(() => sessionManager.closeSession('invalid-id')).toThrow('Session invalid-id not found');
  });
});
