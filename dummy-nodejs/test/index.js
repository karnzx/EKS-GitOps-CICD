'use strict';

/**
 * The assert module is used to perform assertions in Node.js code. For example
 *
 * assert.equal('a', 'b') => false
 * assert.equal('a', 'a') => true
 *
 * You can view the latest docs here: https://nodejs.org/api/assert.html
 */
import { equal, notEqual } from 'assert';
import { getUsers, joinStrings } from '../functions.js';


[
  function testGetUsers () {
    var users = getUsers();

    equal(Array.isArray(users), true, 'Users should be an array');
    equal(users.length, 2);
  },

  function testJoinStrings () {
    var testArr = ['hello', 'world', 'it\'s', 'me, Node.js!']
      , expected = 'hello world it\'s me, Node.js!';

    equal(joinStrings(testArr), expected);
  },

  function exampleFailingJoin () {
    var testArr = ['hello', 'world', 'it\'s', 'me, Node.js!'];

    notEqual(joinStrings(testArr), 'not the expected result');
  }
].forEach(function (fn) {
  try {
    fn();
    console.log('[PASS] - '+ fn.name);
  } catch (e) {
    console.log('[FAIL] - ' + fn.name);
    console.log(e.stack);
  }
})