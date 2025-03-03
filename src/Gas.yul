
object "GasYul" {

	// constructor
    code { 

        datacopy(0, dataoffset("runtime"), datasize("runtime"))

     	setimmutable(0, "admin0", mload(0x20))
     	setimmutable(0, "admin1", mload(0x40))
     	setimmutable(0, "admin2", mload(0x60))
     	setimmutable(0, "admin3", mload(0x80))

        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {
            // Dispatcher
            switch shr(224, calldataload(0))
            case  0xd89d1510/* "administratores(uint n)" */ {
				switch calldataload(4)
				case 0 {
					returnUint(loadimmutable("admin0"))
				}
				case 1 {
					returnUint(loadimmutable("admin1"))
				}
            }

            /* ---------- calldata encoding functions ---------- */
            function returnUint(v) {
                mstore(0, v)
                return(0, 0x20)
            }
            function returnTrue() {
                returnUint(1)
            }
        }
    }
}
