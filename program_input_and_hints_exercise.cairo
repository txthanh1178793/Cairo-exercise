%builtins range_check

from starkware.cairo.common.math import assert_nn_le
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc

struct KeyValue {
    key: felt,
    value: felt,
}

// Builds a DictAccess list for the computation of the cumulative
// sum for each key.
func build_dict(list: KeyValue*, size, dict: DictAccess*) -> (
    dict_end: DictAccess*
) {
    if (size == 0) {
        return (dict_end=dict);
    }

    %{
        #get memory address of list.key, list.value, dict.prev_value
        key_list_addr = ids.list.address_ + ids.KeyValue.key
        value_list_addr = ids.list.address_ + ids.KeyValue.value
        prevalue_dict_addr = ids.dict.address_ + ids.DictAccess.prev_value

        # Populate ids.dict.prev_value using cumulative_sums...
        if memory[key_list_addr] in cumulative_sums.keys(): #check if key existed
            memory[prevalue_dict_addr] = cumulative_sums[memory[key_list_addr]] # if key existed, dict.prev_value = cumulative_sums[key]
        else:
            # else dict.prev_value is 0, cumulative_sums[key] = 0
            memory[prevalue_dict_addr] = 0
            cumulative_sums[memory[key_list_addr]] = 0

        # Add list.value to cumulative_sums[list.key]...
        cumulative_sums[memory[key_list_addr]] += memory[value_list_addr]
    %}
    // Copy list.key to dict.key...
    assert dict.key = list.key;
    // Verify that dict.new_value = dict.prev_value + list.value...
    assert dict.new_value = dict.prev_value + list.value;
    // Call recursively to build_dict()...
    return build_dict(list = list + 2, size = size - 1, dict = dict + 3);
}

// Verifies that the initial values were 0, and writes the final
// values to result.
func verify_and_output_squashed_dict(
    squashed_dict: DictAccess*,
    squashed_dict_end: DictAccess*,
    result: KeyValue*,
    result_size: felt,
) -> (result_size: felt) {
    tempvar diff = squashed_dict_end - squashed_dict;
    if (diff == 0) {
        return (result_size = result_size);
    }

    // Verify prev_value is 0...
    assert squashed_dict.prev_value = 0;
    // Copy key to result.key...
    assert result.key = squashed_dict.key;
    // Copy new_value to result.value...
    assert result.value = squashed_dict.new_value;
    // Call recursively to verify_and_output_squashed_dict...
    return verify_and_output_squashed_dict(squashed_dict = squashed_dict + 3, squashed_dict_end = squashed_dict_end, result = result + 2, result_size = result_size + 1);
}

// Given a list of KeyValue, sums the values, grouped by key,
// and returns a list of pairs (key, sum_of_values).
func sum_by_key{range_check_ptr}(list: KeyValue*, size) -> (
    result: KeyValue*, result_size: felt
) {
    %{
        # Initialize cumulative_sums with an empty dictionary.
        # This variable will be used by ``build_dict`` to hold
        # the current sum for each key.
        cumulative_sums = {}
    %}
    // Allocate memory for dict, squashed_dict and res...
    alloc_locals;
    let (dict: DictAccess*) = alloc();
    let (squashed_dict: DictAccess*) = alloc();
    let (result: KeyValue*) = alloc();

    // Call build_dict()...
    let (dict_end: DictAccess*) = build_dict(list=list, size=size, dict=dict);
    // Call squash_dict()...
    let (squashed_dict_end: DictAccess*) = squash_dict(
        dict_accesses=dict, 
        dict_accesses_end=dict_end, 
        squashed_dict=squashed_dict);
    // Call verify_and_output_squashed_dict()...
    let(result_size) = verify_and_output_squashed_dict(
        squashed_dict=squashed_dict,
        squashed_dict_end=squashed_dict_end,
        result=result,
        result_size=0,
    );
    return (result = result, result_size = result_size);
}

func print_KeyValue(list: KeyValue*, size: felt){
    %{
        kv_size = ids.KeyValue.SIZE
        for i in range(ids.size):
            key_offset = ids.KeyValue.key
            value_offset = ids.KeyValue.value
            print(memory[ids.list.address_ + kv_size * i + key_offset], memory[ids.list.address_ + kv_size * i + value_offset])
    %}
    return();
}

func main{range_check_ptr}(){
    //Create list of KeyValue pairs: (3, 5), (1, 10), (3, 1), (3, 8), (1, 20)
    alloc_locals;
    let (input: KeyValue*) = alloc();
    assert input[0] = KeyValue(key=3, value=5); 
    assert input[1] = KeyValue(key=1, value=10); 
    assert input[2] = KeyValue(key=3, value=1); 
    assert input[3] = KeyValue(key=3, value=8); 
    assert input[4] = KeyValue(key=1, value=20); 

    //call the sum_by_key function
    let (output: KeyValue*, output_size: felt) = sum_by_key{range_check_ptr = range_check_ptr}(list = input, size = 5);

    //print output
    print_KeyValue(list = output, size = output_size);
    return();

}