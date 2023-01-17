import { BigNumber, BigNumberish } from "ethers"
import { string } from "hardhat/internal/core/params/argumentTypes"

const toHex = (val: BigNumberish) => {
    const res = BigNumber.from(val).toHexString()
    console.log(res)
    console.log(res.length)
    return res.replace("0x", "")
}

const serialize = (hexVal: string) => {
    const hex = hexVal.replace("0x", "")
    console.log({ hex, length: hex.length })
    const base16 = BigNumber.from("16")

    let ret0 = BigNumber.from("0"), ret1 = BigNumber.from("0")

    for (let i = 0; i < 32; ++i) {
        ret0 = ret0.add(BigNumber.from(parseInt(hex[i], 16).toString()).mul(base16.pow(31 - i)))
        ret1 = ret1.add(BigNumber.from(parseInt(hex[i + 32], 16).toString()).mul(base16.pow(31 - i)))

        console.log({ i: i, x1: hex[i], x2: hex[32 + i] })
    }

    return [ret0.toString(), ret1.toString()]
}
//"blockHash": ["15868676834665854286711448057219423165", "59045993517242136316030705162720745672"]
const data = serialize("0x4c192662ca7e2a88003cf638e2fd81f2a632911d4f99b61c871cbe8bc0177fbb")

console.log({ data })

const head = toHex("101151913659710339678133574083198943730")
const tail = toHex("220914405414867160112567640421393989563")
const res = "0x" + head + tail

const res1 = BigNumber.from("101151913659710339678133574083198943730").shl(128).or(BigNumber.from("220914405414867160112567640421393989563"))

console.log(res1)
console.log(res === "0x4c192662ca7e2a88003cf638e2fd81f2a632911d4f99b61c871cbe8bc0177fbb" && res === res1.toHexString())