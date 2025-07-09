local handler = require "handlers.invalidate.handler"

local http = require "handlers.utils.http"
local get_incoming_request = http.get_incoming_request
local send_response_to_client = http.send_response_to_client

local incoming_request = get_incoming_request()
local reponse = handler:execute(incoming_request)
send_response_to_client(reponse)
