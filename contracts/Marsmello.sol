// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Marsmello is ERC20 {
    constructor() ERC20(m_name, m_symbol) {
        _mint(msg.sender, m_supply * 10**decimals());
        deploy_time = block.timestamp;
        factories.push(
            Factory("Void", address(this), 0, 0, 0, CoOrdinates(0, 0))
        );
    }

    string m_name = "MarsMello";
    string m_symbol = "MLO";
    uint256 m_supply = 10**9;
    uint256 deploy_time;
    uint256 randomness = 12345678901234567890;
    uint256 land_price = 1000 * 10**decimals();
    uint256 factory_price = 1000 * 10**decimals();

    uint256 factory_count = 0;
    struct Land {
        address owner;
        uint256 seed;
        uint16[5] ores;
        uint256 ontop;
    }
    struct Factory {
        string name;
        address owner;
        uint64 ftype;
        uint64 efficiency;
        uint256 lastclaimed;
        CoOrdinates placedon;
    }
    struct User {
        uint256[] factories;
        CoOrdinates[] lands;
    }
    struct CoOrdinates {
        int256 x;
        int256 y;
    }
    struct Relay {
        address owner;
        uint256 seed;
        uint16[5] ores;
        Factory ontop;
    }
    IERC20[5] private tokens = [
        IERC20(0x110472D9B5661DC1d8BA8C637Dbde1f5a813cD8A),
        IERC20(0x7155651d11C869f76BE988cf30BE3B856f29E905),
        IERC20(0xe8D98e3331C0434D38FfB8041eF2EF233C41Cf70),
        IERC20(0x38a3FD50BF7240988639D7DA8A0EcD91052AF1d1),
        IERC20(0x8042A576cB35d83cbECE64e211BF0570F72e4Cfd)
    ];

    mapping(int256 => mapping(int256 => Land)) private lands;
    Factory[] private factories;
    mapping(address => User) private users;

    modifier landOwner(int256 x, int256 y) {
        require(
            lands[x][y].owner == msg.sender,
            "Land doesn't belong to you !"
        );
        _;
    }
    modifier factoryOwner(uint256 id) {
        require(
            factories[id].owner == msg.sender,
            "Factory doesn't belong to you !"
        );
        _;
    }

    function getUserData(address user)
        public
        view
        returns (uint256[] memory, CoOrdinates[] memory)
    {
        return (users[user].factories, users[user].lands);
    }

    function getLandPrice() public view returns (uint256) {
        return (land_price);
    }

    function mintFactory(string memory name, uint8 ftype) public {
        require(
            balanceOf(msg.sender) >= factory_price,
            "Not enough MLO in your wallet to buy land !"
        );
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    randomness,
                    blockhash(block.number - 1),
                    factories.length
                )
            )
        );
        factories.push(
            Factory(
                name,
                msg.sender,
                ftype,
                uint64(51 + (seed % 50)),
                0,
                CoOrdinates(0, 0)
            )
        );
        _transfer(msg.sender, address(this), factory_price);
        users[msg.sender].factories.push(factories.length - 1);
    }

    function calcOreDist(uint256 seed) public pure returns (uint16[5] memory) {
        return [
            uint16(15 + (seed % 13)),
            uint16(5 + (seed % 11)),
            uint16(5 + (seed % 7)),
            uint16(3 + (seed % 5)),
            uint16(seed % 5)
        ];
    }

    function mintLand(int256 x, int256 y) public {
        require(x != 0 || y != 0, "Can't buy spawn !");
        require(x < 1000000000 || y != 0, "Can't buy spawn !");
        require(lands[x][y].owner == address(0x0), "Land already exists !");
        require(
            balanceOf(msg.sender) >= land_price,
            "Not enough MLO in your wallet to buy land !"
        );
        _transfer(msg.sender, address(this), land_price);
        land_price += land_price / 100;
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    randomness,
                    blockhash(block.number - 1),
                    land_price
                )
            )
        );
        lands[x][y] = Land(msg.sender, seed, calcOreDist(seed), 0);
        users[msg.sender].lands.push(CoOrdinates(x, y));
    }

    function _clearLand(CoOrdinates memory c) private {
        if (c.x != 0 || c.y != 0) lands[c.x][c.y].ontop = 0;
    }

    function _clearFactory(uint256 id) private {
        if (id != 0) {
            factories[id].placedon = CoOrdinates(0, 0);
            factories[id].lastclaimed = 0;
        }
    }

    function placeFactory(
        uint256 factory_id,
        int256 x,
        int256 y
    ) public landOwner(x, y) factoryOwner(factory_id) {
        _clearFactory(lands[x][y].ontop);
        _clearLand(factories[factory_id].placedon);

        lands[x][y].ontop = factory_id;
        factories[factory_id].placedon = CoOrdinates(x, y);
        factories[factory_id].lastclaimed = block.timestamp;
    }

    function transferLand(
        address to,
        int256 x,
        int256 y
    ) public landOwner(x, y) {
        _clearFactory(lands[x][y].ontop);
        _clearLand(CoOrdinates(x, y));
        lands[x][y].owner = to;
        for (uint256 i = 0; i < users[msg.sender].lands.length; i++) {
            if (
                users[msg.sender].lands[i].x == x &&
                users[msg.sender].lands[i].y == y
            ) {
                users[msg.sender].lands[i] = CoOrdinates(0, 0);
                break;
            }
        }
        users[to].lands.push(CoOrdinates(x, y));
    }

    function transferFactory(address to, uint256 factory_id)
        public
        factoryOwner(factory_id)
    {
        Factory storage f = factories[factory_id];
        _clearLand(f.placedon);
        _clearFactory(factory_id);
        f.owner = to;
        for (uint256 i = 0; i < users[msg.sender].factories.length; i++) {
            if (users[msg.sender].factories[i] == factory_id) {
                users[msg.sender].factories[i] == 0;
                break;
            }
        }
        users[to].factories.push(factory_id);
    }

    function claimAll() public {
        uint256[5] memory amounts;
        uint64 t;
        for (uint256 i = 0; i < users[msg.sender].factories.length; i++) {
            Factory storage f = factories[users[msg.sender].factories[i]];
            if (f.placedon.x != 0 || f.placedon.y != 0) {
                t = f.ftype % 10;
                if (t > 0) {
                    t--;
                    amounts[t] +=
                        (lands[f.placedon.x][f.placedon.y].ores[t] *
                            f.efficiency *
                            10**18) /
                        36;
                }
            }
        }
        for (uint256 i = 0; i < 5; i++) {
            if (amounts[i] > 0)
                require(tokens[i].transfer(msg.sender, amounts[i]));
        }
        for (uint256 i = 0; i < users[msg.sender].factories.length; i++) {
            Factory storage f = factories[users[msg.sender].factories[i]];
            if (f.placedon.x != 0 || f.placedon.y != 0) {
                f.lastclaimed = block.timestamp;
            }
        }
    }

    function getArea(int256 x, int256 y)
        public
        view
        returns (Relay[41][41] memory)
    {
        Relay[41][41] memory r;
        for (uint256 i = 0; i < 41; i++) {
            for (uint256 j = 0; j < 41; j++) {
                Land memory l = lands[x - 20 + int256(i)][y - 20 + int256(j)];
                r[i][j] = Relay(l.owner, l.seed, l.ores, factories[l.ontop]);
            }
        }
        return r;
    }
}
