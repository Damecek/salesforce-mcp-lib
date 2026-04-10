import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  LoginRequiredError,
  RemoteMcpError,
  SalesforceAuthError,
} from '../src/errors.js';

describe('SalesforceAuthError', () => {
  it('is an instance of Error (prototype chain restored)', () => {
    const err = new SalesforceAuthError('auth failed');
    assert.ok(err instanceof Error);
  });

  it('is an instance of SalesforceAuthError', () => {
    const err = new SalesforceAuthError('auth failed');
    assert.ok(err instanceof SalesforceAuthError);
  });

  it('.name === "SalesforceAuthError"', () => {
    const err = new SalesforceAuthError('auth failed');
    assert.equal(err.name, 'SalesforceAuthError');
  });

  it('preserves message', () => {
    const err = new SalesforceAuthError('invalid grant');
    assert.equal(err.message, 'invalid grant');
  });

  it('has a stack trace', () => {
    const err = new SalesforceAuthError('auth failed');
    assert.ok(typeof err.stack === 'string');
    assert.ok(err.stack.length > 0);
  });
});

describe('RemoteMcpError', () => {
  it('is an instance of Error (prototype chain restored)', () => {
    const err = new RemoteMcpError('bad response', 500, '{}');
    assert.ok(err instanceof Error);
  });

  it('is an instance of RemoteMcpError', () => {
    const err = new RemoteMcpError('bad response', 500, '{}');
    assert.ok(err instanceof RemoteMcpError);
  });

  it('preserves .statusCode and .responseBody', () => {
    const err = new RemoteMcpError('not found', 404, '{"error":"missing"}');
    assert.equal(err.statusCode, 404);
    assert.equal(err.responseBody, '{"error":"missing"}');
    assert.equal(err.message, 'not found');
  });

  it('handles zero statusCode and empty body', () => {
    const err = new RemoteMcpError('unknown', 0, '');
    assert.equal(err.statusCode, 0);
    assert.equal(err.responseBody, '');
    assert.equal(err.message, 'unknown');
  });
});

describe('LoginRequiredError', () => {
  it('is an instance of SalesforceAuthError', () => {
    const err = new LoginRequiredError('run login first');
    assert.ok(err instanceof SalesforceAuthError);
    assert.ok(err instanceof LoginRequiredError);
  });

  it('preserves the actionable message', () => {
    const err = new LoginRequiredError('run login first');
    assert.equal(err.message, 'run login first');
    assert.equal(err.name, 'LoginRequiredError');
  });
});
