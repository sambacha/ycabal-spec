SELECT 
    sum(t.gas_used) as total_gas,
    sum(t.gas_used * t.gas_price / 1e18 * (SELECT price FROM prices.layer1_usd_eth ORDER BY minute desc LIMIT 1)) as total_usd,
    sum(t.gas_used / 12000000) * 14 / 60 / 60 as n_hours_used,
    sum(t.gas_used / 12000000) as total_blocks
FROM ethereum.transactions t
WHERE t."to" = '\x860bd2dba9Cd475A61E6d1b45e16c365F6D78F66'
    OR t."to" = '\xb958a8f59ac6145851729f73c7a6968311d8b633'
    OR t."to" = '\x85c5c26dc2af5546341fc1988b9d178148b4838b'
    OR t."to" = '\x8018280076d7fa2caa1147e441352e8a89e1ddbe'
    OR t."to" = '\x693c188e40f760ecf00d2946ef45260b84fbc43e'
    OR t."to" = '\x0000000000c90bc353314b6911180ed7e06019a9'
    OR t."to" = '\xce5702e94ad38c061e44a4a049cc29261f992846'
    OR t."to" = '\x514fd3b8109cfb7cde4b17e4912fd56690c23145'
    OR t."to" = '\xa57bd00134b2850b2a1c55860c9e9ea100fdd6cf'
    OR t."to" = '\x8977c88d021882ef712200142062ed636031a3fd'
    OR t."to" = '\x985149cf58af5d2f50dee363a52ed4e0acc10cf1'
    OR t."to" = '\xb14a74c43ce0bf8f7912f7f1f8feb90b4b5f466b'
    OR t."to" = '\xc2a694c5ced27e3d3a5a8bd515a42f2b89665003'
    OR t."to" = '\x00000000b1786c9698c160d78232c78d6f6474fe'
    OR t."to" = '\x000000000000deab340f067535869a0e5226e58a'
    OR t."to" = '\x28f2914ebb7ac98feefa7f6008a76e70bfa7963c'
    OR t."to" = '\x9799b475dec92bd99bbdd943013325c36157f383'
    OR t."to" = '\xf6fb09a41fa6c18cebc1e7c6f75a8664d69e4d48'
    OR t."to" = '\xe9519677e6ec8d2d6bfab92a059529fea6075d37'
    OR t."to" = '\x000000000000006f6502b7f2bbac8c30a3f67e9a'
    OR t."to" = '\xf1ad4bfdf8829d55ec0ce7900ef9d122b2610673'
    OR t."to" = '\x8a3960472b3d63894b68df3f10f58f11828d6fd9'
    OR t."to" = '\x762ed657b76372f8c08c6f7e0aa4170658c4ca35'
    OR t."to" = '\x78a55b9b3bbeffb36a43d9905f654d2769dc55e8'
    OR t."to" = '\xf443253607dbde5bda77c358c9b9f244d819e25c'
    OR t."to" = '\xe33c8e3a0d14a81f0dd7e174830089e82f65fc85'

