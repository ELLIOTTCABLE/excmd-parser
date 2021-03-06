import termkit, {ScreenBuffer} from 'terminal-kit'

import {Parser, Checkpoint} from '../dist/excmd.mjs'

const term = termkit.terminal

function describeExpression(output: ScreenBuffer, expr: Expression) {
   output.put({markup: true, y: 1, x: 0}, `Count: ^_${expr.count}^:`)
   output.put({markup: true, y: 2, x: 0}, `Command: ^_${expr.command}^:`)

   const positionals = expr.getPositionals()
   if (positionals.length) {
      output.put({y: 4, x: 0}, `Positionals (including ambiguous flag-payloads):`)

      for (let [idx, positional] of positionals.entries()) {
         output.put({markup: true, y: 5 + idx, x: 0}, `${idx}. "${positional}"`)
      }
   }

   const flagsStart = positionals.length ? 7 + positionals.length : 5

   // TODO: Hmm, I wonder if I should add a more efficient ‘are there any flags at all’ test ...
   if (expr.flags.length) {
      output.put({y: flagsStart - 1, x: 0}, `Flags:`)

      expr.forEachFlag(function(flag, payload, idx) {
         if (payload)
            output.put(
               {markup: true, y: flagsStart + idx, x: 0},
               `- ${flag}: "${payload}"`,
            )
         else
            output.put(
               {markup: true, y: flagsStart + idx, x: 0},
               `- ${flag} (no payload)`,
            )
      })
   }
}

function describeCheckpoint(output: ScreenBuffer, cp: Checkpoint) {
   const state = cp.automaton_status

   switch (state) {
      case 'Accepted':
      case 'Rejected':
         output.put({markup: true, x: 0, y: 0}, `State: ^_${state}^:`)
         break

      case 'InputNeeded':
      case 'Shifting':
      case 'AboutToReduce':
      case 'HandlingError':
         const {
            command,
            incoming_symbol: symbol,
            incoming_symbol_type: type,
            incoming_symbol_category: category,
         } = cp

         if (typeof symbol === 'undefined')
            output.put({markup: true, x: 0, y: 0}, `State: ^_${state}^: (initial)`)
         else {
            const symbol_desc = `${symbol} : (${type}) ${category}`

            output.put(
               {markup: true, x: 0, y: 0},
               `State: ^_${state}^:, incoming: ^_${symbol_desc}^:, current command: ^_${command}^:`,
            )
         }
   }

   draw(output)
}

function displayStack(output: ScreenBuffer, cp: Checkpoint) {
   for (let el of cp.beforeStack) {
      output.put({}, el.incoming_symbol)
   }
}

function onChange(input: TextBuffer, output: ScreenBuffer) {
   const textContent = input.getText()
   const start: Checkpoint = Parser.startExpressionWithString(textContent)

   output.fill({char: ' '})
   output.moveTo(0, 0)

   start.continue({
      onAccept: function(expr) {
         output.put({}, 'Input accepted!\n')
         describeExpression(output, expr)
      },
      onFail: function(lastGood, errorAt) {
         displayStack(output, lastGood)
      },
   })
   draw(output)
}

// ### Ignore me, mundane terminal-setup noise follows.

function handleKeypress(buf: TextBuffer, key: string) {
   const keyDesc = '^y ' + key + ' '

   // In terminal-kit, `key` is always more than one codepoint in length if it's a special keypress.
   if (key.length === 1) {
      showNotice(keyDesc, false)

      buf.insert(key)
      buf.drawCursor()
      draw(buf, true)
   } else {
      switch (key) {
         // look ma, I'm implementing a text-editor in JavaScript. <.<
         case 'LEFT':
            showNotice(keyDesc, true)
            buf.moveBackward()
            buf.drawCursor()
            buf.dst.drawCursor()
            break

         case 'RIGHT':
            showNotice(keyDesc, true)
            buf.moveForward()
            buf.drawCursor()
            buf.dst.drawCursor()
            break

         case 'UP':
            showNotice(keyDesc, true)
            buf.moveUp()
            buf.moveInBound()
            buf.drawCursor()
            buf.dst.drawCursor()
            break

         case 'DOWN':
            showNotice(keyDesc, true)
            buf.moveDown()
            buf.moveInBound()
            buf.drawCursor()
            buf.dst.drawCursor()
            break

         case 'BACKSPACE':
            showNotice(keyDesc, false)
            buf.backDelete()
            buf.drawCursor()
            draw(buf, true)
            break

         case 'ENTER':
            showNotice(keyDesc, false)
            buf.newLine()
            buf.drawCursor()
            draw(buf, true)
            break

         case 'CTRL_C':
            showNotice(' Buh-bye 💖 ! ', true)
            term.processExit(1)
            break

         default:
            throw new Error('Unhandled special key: ' + key)
      }
   }
}

// I'm using the "alternate screenbuffer" of the terminal; this ensures the user's command-line
// history isn't cluttered with repeated interactive output from this demo. It has some annoying
// side-effects, which I try to mitigate below ...
function setupAltMode() {
   // Setting up the terminal, swtiching to the alternate screenbuffer;
   term.fullscreen(true)
   term.grabInput(true)

   // Horrible hack to freeze the Node.js event-loop long enough for a user to see output;
   function sleep(seconds: number) {
      let msecs = seconds * 1000
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, msecs)
   }

   // Ensuring a clean exit, and a return to the users' expected terminal-state
   function onExit(code) {
      term.grabInput(false)
      sleep(0.5)
      term.fullscreen(false)
   }

   process.once('exit', onExit)
   process.once('SIGINT', onExit)
}

function moveToEnd(buf: TextBuffer) {
   const {width, height} = buf.getContentSize()
   buf.moveToLine(height - 1)
   buf.moveToEndOfLine()
}

// ... now we start actually setting up the terminal!

setupAltMode()

// Create a text-buffer to hold the user's input
const screen = new termkit.ScreenBuffer({dst: term})

const notice = new termkit.ScreenBuffer({dst: screen, y: term.height - 1, x: term.width})

let drawTimeout: NodeJS.Timeout = null
let drawPending = false
function draw(buf: TextBuffer | ScreenBuffer, immediate = false) {
   // First, go ahead and aggressively perform any virtual drawing to parent buffers:
   let next = buf
   do {
      next.draw()
      next = next.dst
   } while (next.dst instanceof termkit.ScreenBuffer)

   // If there's been a draw recently ...
   if (immediate === false && null !== drawTimeout) drawPending = true
   // ... else draw to the actual terminal, and schedule a check for the next draw.
   else {
      if (null !== drawTimeout) clearTimeout(drawTimeout)
      if (drawPending) drawPending = false

      next.draw({delta: true})
      next.drawCursor()

      drawTimeout = setTimeout(function checkForScheduledDraw() {
         drawTimeout = null

         if (drawPending) {
            next.draw({delta: true})
            next.drawCursor()

            drawPending = false
         }
      }, 500)
   }
}

let noticeTimeout: NodeJS.Timeout = null
function showNotice(str: string, drawNow = true) {
   if (noticeTimeout !== null) clearTimeout(noticeTimeout)

   // FIXME: This shouldn't be necessary; the below `put` at 0,0 should clear it, right? ...
   notice.fill({char: ' '})
   notice.draw()

   notice.x = term.width - termkit.stringWidth(str) - 1
   notice.put({x: 0, y: 0, markup: true}, str)
   drawNow ? draw(notice) : notice.draw()

   noticeTimeout = setTimeout(function clearNotice() {
      notice.fill({char: ' '})
      draw(notice)

      noticeTimeout = null
   }, 1000)
}

const intro = new termkit.ScreenBuffer({dst: screen, y: term.height - 2})
intro.put(
   {},
   `Welcome! Edit the input above to see how it parses.
(↩  to watch the detailed, iterative process; ⌃ C to exit.)`,
)
intro.draw()

const input = new termkit.TextBuffer({
   dst: screen,
   height: 3,
   x: 3,
   y: term.height - 5,
})

input.setText(process.argv[2] || '')
moveToEnd(input)
input.drawCursor()
draw(input)

const output = new termkit.ScreenBuffer({dst: screen, y: 0, height: term.height - 6})

term.on('key', handleKeypress.bind(null, input))

// ### Aaaaand we're off!

term.on('key', onChange.bind(null, input, output))
