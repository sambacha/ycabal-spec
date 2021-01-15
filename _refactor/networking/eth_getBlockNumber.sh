curl --max-time 6000 --request POST 'http://18.216.213.235:8545' \
--header 'Content-Type: text/plain' \
--data-raw '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0xF", true], "id":1}'
