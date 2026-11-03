// Characterization only: true demonstrates that local validators lack a content gate.
// This does not call a model or demonstrate a successful model jailbreak.
import { validateScript, validateTutorReply } from '../../backend/src/protocol.js';
const reply = 'You are worthless and you should give up.';
const line = 'Keep studying.';
console.log(JSON.stringify({
  tutorAcceptsDemeaningReply: validateTutorReply({reply}).reply === reply,
  scriptAcceptsDemeaningReaction: validateScript({greeting:line,demand:line,reason:line,
    correct:[line],wrong:[reply],pass:line,fail:line,sendoff:line}).wrong[0] === reply
}));
