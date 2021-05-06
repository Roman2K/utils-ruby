const readline = require('readline')

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false,
})

rl.on('line', req => {
  req = JSON.parse(req)
  const writeResult = (status, val) => {
    process.stdout.write(JSON.stringify({
      id: req.id,
      status: status,
      value: val,
    }))
    process.stdout.write("\n")
  }
  const res = eval(req.src)
  if (res instanceof Promise) {
    res.
      then(val => writeResult("ok", val)).
      catch(val => writeResult("err", val))
  } else {
    writeResult("ok", res)
  }
})
