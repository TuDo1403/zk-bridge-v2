import { BigNumber } from "ethers";
import { arrayify, hexlify, splitSignature } from "ethers/lib/utils";
const data = BigNumber.from("0xc5b75a7cdadfef74825e58d4b122afe95c5b079748f645d9d83698dff2f16abe60fe4384fe8387a2b82692ece949e1939f16c539f1ea79e4785ab09d1dd7186f01")
const bytes = arrayify(data)
bytes[64] += 27
console.log({ bytes })
const newData = hexlify(bytes)
console.log({ newData })
const sig = splitSignature(newData)

console.log({ sig })