package tests

import "core:encoding/json"
import "core:log"
import "core:strings"
import "core:testing"

import "src:common"
import "src:server"

TestWriterBuffer :: struct {
	data: [dynamic]u8,
}

test_write :: proc(handle: rawptr, data: []byte) -> (int, int) {
	buffer := cast(^TestWriterBuffer)handle
	for b in data {
		append(&buffer.data, b)
	}
	return len(data), 0
}

buffer_contains :: proc(buffer: ^TestWriterBuffer, needle: string) -> bool {
	return strings.contains(string(buffer.data[:]), needle)
}

count_substring :: proc(s, substr: string) -> int {
	count := 0
	start := 0
	for {
		idx := strings.index(s[start:], substr)
		if idx == -1 do break
		count += 1
		start += idx + len(substr)
	}
	return count
}

cancel_test_setup :: proc() -> (writer: server.Writer, buffer: ^TestWriterBuffer) {
	buffer = new(TestWriterBuffer)
	writer = server.make_writer(test_write, buffer)

	for req in server.requests {
		json.destroy_value(req.value)
	}
	delete(server.requests)
	delete(server.deletings)

	server.requests = make([dynamic]server.Request, context.allocator)
	server.deletings = make([dynamic]server.Request, context.allocator)
	return
}

cancel_test_teardown :: proc(buffer: ^TestWriterBuffer) {
	for req in server.requests {
		json.destroy_value(req.value)
	}
	delete(server.requests)
	delete(server.deletings)
	delete(buffer.data)
	free(buffer)
}

@(test)
cancel_request_numeric_id :: proc(t: ^testing.T) {
	writer, buffer := cancel_test_setup()
	defer cancel_test_teardown(buffer)

	old_running := common.config.running
	common.config.running = false
	defer common.config.running = old_running

	req_value, err := json.parse_string(`{"jsonrpc":"2.0","id":7,"method":"shutdown"}`, parse_integers = true)
	if err != json.Error.None {
		log.errorf("failed to parse test JSON: %v", err)
		return
	}

	append(&server.requests, server.Request{id = i64(7), value = req_value, is_notification = false})
	append(&server.deletings, server.Request{id = i64(7)})

	server.consume_requests(&common.config, &writer)

	if !buffer_contains(buffer, `"id": 7`) {
		log.error("expected response for id 7")
	}
	if !buffer_contains(buffer, `"code": -32800`) {
		log.error("expected RequestCancelled code -32800")
	}
	if buffer_contains(buffer, `"result"`) {
		log.error("expected error response, not success result")
	}
}

@(test)
cancel_request_string_id :: proc(t: ^testing.T) {
	writer, buffer := cancel_test_setup()
	defer cancel_test_teardown(buffer)

	old_running := common.config.running
	common.config.running = false
	defer common.config.running = old_running

	req_value, err := json.parse_string(`{"jsonrpc":"2.0","id":"abc","method":"shutdown"}`, parse_integers = true)
	if err != json.Error.None {
		log.errorf("failed to parse test JSON: %v", err)
		return
	}

	append(&server.requests, server.Request{id = "abc", value = req_value, is_notification = false})
	append(&server.deletings, server.Request{id = "abc"})

	server.consume_requests(&common.config, &writer)

	if !buffer_contains(buffer, `"id": "abc"`) {
		log.error("expected response for id 'abc'")
	}
	if !buffer_contains(buffer, `"code": -32800`) {
		log.error("expected RequestCancelled code -32800")
	}
	if buffer_contains(buffer, `"result"`) {
		log.error("expected error response, not success result")
	}
}

@(test)
cancel_unrelated_request_survives :: proc(t: ^testing.T) {
	writer, buffer := cancel_test_setup()
	defer cancel_test_teardown(buffer)

	old_running := common.config.running
	common.config.running = false
	defer common.config.running = old_running

	req_value_42, err1 := json.parse_string(`{"jsonrpc":"2.0","id":42,"method":"shutdown"}`, parse_integers = true)
	if err1 != json.Error.None {
		log.errorf("failed to parse test JSON for id 42: %v", err1)
		return
	}

	req_value_43, err2 := json.parse_string(`{"jsonrpc":"2.0","id":43,"method":"shutdown"}`, parse_integers = true)
	if err2 != json.Error.None {
		log.errorf("failed to parse test JSON for id 43: %v", err2)
		return
	}

	append(&server.requests, server.Request{id = i64(42), value = req_value_42, is_notification = false})
	append(&server.requests, server.Request{id = i64(43), value = req_value_43, is_notification = false})
	append(&server.deletings, server.Request{id = i64(99)})

	server.consume_requests(&common.config, &writer)

	output := string(buffer.data[:])

	if !buffer_contains(buffer, `"id": 42`) {
		log.error("expected response for id 42")
	}
	if !buffer_contains(buffer, `"id": 43`) {
		log.error("expected response for id 43")
	}
	if strings.contains(output, `"code": -32800`) {
		log.error("expected no cancellation for unrelated ids")
	}
}

@(test)
cancel_removes_only_target :: proc(t: ^testing.T) {
	writer, buffer := cancel_test_setup()
	defer cancel_test_teardown(buffer)

	old_running := common.config.running
	common.config.running = false
	defer common.config.running = old_running

	req_value_1, err1 := json.parse_string(`{"jsonrpc":"2.0","id":1,"method":"shutdown"}`, parse_integers = true)
	if err1 != json.Error.None {
		log.errorf("failed to parse test JSON for id 1: %v", err1)
		return
	}

	req_value_2, err2 := json.parse_string(`{"jsonrpc":"2.0","id":2,"method":"shutdown"}`, parse_integers = true)
	if err2 != json.Error.None {
		log.errorf("failed to parse test JSON for id 2: %v", err2)
		return
	}

	append(&server.requests, server.Request{id = i64(1), value = req_value_1, is_notification = false})
	append(&server.requests, server.Request{id = i64(2), value = req_value_2, is_notification = false})
	append(&server.deletings, server.Request{id = i64(2)})

	server.consume_requests(&common.config, &writer)

	output := string(buffer.data[:])

	response_count := count_substring(output, "Content-Length:")
	if response_count != 2 {
		log.errorf("expected 2 responses, got %d", response_count)
	}
	if !buffer_contains(buffer, `"id": 1`) {
		log.error("expected response for id 1")
	}
	if !buffer_contains(buffer, `"id": 2`) {
		log.error("expected response for id 2")
	}
	if !buffer_contains(buffer, `"code": -32800`) {
		log.error("expected cancellation error")
	}
	if !buffer_contains(buffer, `"result"`) {
		log.error("expected normal result for surviving request")
	}
}
