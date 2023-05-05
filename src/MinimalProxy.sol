// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IImplementation {
    function initialise() external; 
}

contract MinimalProxy {
    
    address[] public proxies;

    // EVENTS
    event ProxyCreated(address indexed proxy);
    
    /// @dev Deploys a new minimal contract via create2
    /// @param implementation Address of Implementation contract
    /// @param salt Random number of choice
    function deploy(address implementation, uint256 salt) external returns (address) {
        
        // convert the address to 20 bytes
        bytes20 implementationBytes = bytes20(implementation);

        // address to assign minimal proxy
        address proxy;

        assembly {
            
            // get free memory pointer
            let pointer := mload(0x40)
        
            // mstore 32 bytes at the start of free memory 
            mstore(pointer, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)

            // overwrite the trailing 0s above with implementation contract's byte address 
            // add(pointer + 20 bytes) =>  0x14 = 20
            mstore(add(pointer, 0x14), implementationBytes)
           
            // store 32 bytes to memory starting at "clone" + 40 bytes
            // 0x28 = 40
            mstore(add(pointer, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)

            // create a new contract, send 0 Ether
            proxy := create2(0, pointer, 0x37, salt)
        }
      
        proxies.push(proxy);
        emit ProxyCreated(proxy);

        return proxy;
    }

    function init(address proxy) external {
        // Initialise minimal proxy
        IImplementation(proxy).initialise();
    }


    /*
    When calculating the deployment address we need to use the creation code for the minimal proxy,
    not the logic contract that the minimal proxy points to.
    */

    /// @dev Get address of contract to be deployed
    /// @param salt Random number of choice
    /// @param implementation Address of Implementation contract
    function getAddress(address implementation, uint256 salt) public view returns (address) {
        //bytes32 salt = keccak256(abi.encodePacked(salt, _sender));
        bytes memory bytecode = getByteCode(implementation);

        // find hash
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        // cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    /// @dev Get creation code of contract to deploy
    /// @param implementation Address of Implementation contract proxy will delegateCall to 
    /// @return bytes Bytecode of creaton code to be passed into getAddress()
    function getByteCode(address implementation) internal pure returns (bytes memory) {
        bytes10 creation = 0x3d602d80600a3d3981f3;
        bytes10 prefix = 0x363d3d373d3d3d363d73;
        bytes20 targetBytes = bytes20(implementation);
        bytes15 suffix = 0x5af43d82803e903d91602b57fd5bf3;
        
        return abi.encodePacked(creation, prefix, targetBytes, suffix);
    }

}