#[mode(test)]
module ptb::ptb_tests;

use ptb::ptb;
use std::unit_test::assert_eq;

#[test]
fun ptb() {
    let mut ptb = ptb::new();
    let clock = ptb::clock();
    let arg = ptb.command(
        ptb::move_call(
            @0x2.to_string(),
            "clock",
            "timestamp_ms",
            vector[clock],
            vector[],
        ),
    );

    let coin = ptb.command(ptb::split_coins(ptb::gas(), vector[arg]));

    ptb.command(ptb::transfer_objects(vector[coin], ptb::pure(@0)));

    assert_eq!(arg.idx(), 0);
}

#[test]
fun pas_command_with_ext_inputs() {
    ptb::move_call(
        @0x0.to_string(),
        "demo_usd",
        "resolve_transfer",
        vector[
            ptb::ext_input("request"), // TODO: consider namespaces here?
            ptb::ext_input("rule_arg"),
            ptb::clock(),
        ],
        vector["magic::usdc_app::DEMO_USDC"],
    );

    // TODO: compiler panic!
    // std::debug::print(&_mc);
}
