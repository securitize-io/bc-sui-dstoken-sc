#[test_only]
module securitize::rule_wrapper_tests;

use securitize::rule_wrapper;
use securitize::test_helpers::TEST_VOLORO;

public struct TestRule has drop {
    value: u64,
}

#[test]
fun test_init_wrapper_create_and_borrow() {
    let rule = TestRule { value: 42 };
    let wrapper = rule_wrapper::new_init<TEST_VOLORO, TestRule>(rule);

    let ref = rule_wrapper::borrow_init(&wrapper);
    assert!(ref.value == 42);

    let rule = rule_wrapper::unwrap_init(wrapper);
    assert!(rule.value == 42);
}

#[test]
fun test_init_wrapper_mutate() {
    let rule = TestRule { value: 42 };
    let mut wrapper = rule_wrapper::new_init<TEST_VOLORO, TestRule>(rule);

    rule_wrapper::borrow_init_mut(&mut wrapper).value = 100;

    let ref = rule_wrapper::borrow_init(&wrapper);
    assert!(ref.value == 100);

    let rule = rule_wrapper::unwrap_init(wrapper);
    assert!(rule.value == 100);
}

#[test]
fun test_update_wrapper_create_and_borrow() {
    let rule = TestRule { value: 99 };
    let wrapper = rule_wrapper::new_update<TEST_VOLORO, TestRule>(rule);

    let ref = rule_wrapper::borrow_update(&wrapper);
    assert!(ref.value == 99);

    let rule = rule_wrapper::unwrap_update(wrapper);
    assert!(rule.value == 99);
}

#[test]
fun test_update_wrapper_mutate() {
    let rule = TestRule { value: 99 };
    let mut wrapper = rule_wrapper::new_update<TEST_VOLORO, TestRule>(rule);

    rule_wrapper::borrow_update_mut(&mut wrapper).value = 200;

    let ref = rule_wrapper::borrow_update(&wrapper);
    assert!(ref.value == 200);

    let rule = rule_wrapper::unwrap_update(wrapper);
    assert!(rule.value == 200);
}
