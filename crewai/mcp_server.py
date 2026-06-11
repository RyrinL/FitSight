"""crewAI MCP server — exposes FitSight crew tools to Claude Code."""

import json
import sys
from agents.fitness_crew import fitness_crew


TOOLS = [
    {
        "name": "review_swift_code",
        "description": "Swift Architect reviews Swift/SwiftUI code for concurrency and architecture",
        "inputSchema": {
            "type": "object",
            "properties": {
                "code": {"type": "string", "description": "Swift code to review"},
            },
            "required": ["code"],
        },
    },
    {
        "name": "review_healthkit",
        "description": "HealthKit Specialist reviews code for correct HealthKit usage, permissions, and privacy",
        "inputSchema": {
            "type": "object",
            "properties": {
                "code": {"type": "string", "description": "Swift code or feature description to review"},
            },
            "required": ["code"],
        },
    },
    {
        "name": "qa_review",
        "description": "QA Engineer writes a test plan and identifies edge cases for a fitness feature",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature": {"type": "string", "description": "Feature name or description to test"},
            },
            "required": ["feature"],
        },
    },
    {
        "name": "ui_review",
        "description": "SwiftUI UI Specialist reviews a screen for accessibility, dark mode, layout, and HIG compliance",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature": {"type": "string", "description": "SwiftUI screen name or code to review"},
            },
            "required": ["feature"],
        },
    },
    {
        "name": "ux_review",
        "description": "Fitness UX Specialist reviews a feature against Apple HIG and fitness app best practices",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature": {"type": "string", "description": "Feature description to review"},
            },
            "required": ["feature"],
        },
    },
    {
        "name": "full_review",
        "description": "Run all 5 agents (Swift Architect, HealthKit, QA, UI, UX) on a feature and code",
        "inputSchema": {
            "type": "object",
            "properties": {
                "code": {"type": "string", "description": "Swift code to review"},
                "feature": {"type": "string", "description": "Feature description"},
            },
            "required": ["code", "feature"],
        },
    },
]


def run_crew(code: str = "", feature: str = "") -> str:
    result = fitness_crew.kickoff(inputs={"code": code, "feature": feature})
    return str(result)


def handle_request(request: dict) -> dict:
    method = request.get("method")

    if method == "tools/list":
        return {"tools": TOOLS}

    if method == "tools/call":
        tool = request.get("params", {}).get("name")
        args = request.get("params", {}).get("arguments", {})

        dispatch = {
            "review_swift_code":  lambda: run_crew(code=args["code"], feature=""),
            "review_healthkit":   lambda: run_crew(code=args["code"], feature=""),
            "qa_review":          lambda: run_crew(code="", feature=args["feature"]),
            "ui_review":          lambda: run_crew(code="", feature=args["feature"]),
            "ux_review":          lambda: run_crew(code="", feature=args["feature"]),
            "full_review":        lambda: run_crew(code=args.get("code", ""), feature=args.get("feature", "")),
        }

        fn = dispatch.get(tool)
        if fn:
            return {"content": [{"type": "text", "text": fn()}]}

    return {"error": {"code": -32601, "message": "Method not found"}}


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            response = {
                "jsonrpc": "2.0",
                "id": request.get("id"),
                **handle_request(request),
            }
            print(json.dumps(response), flush=True)
        except Exception as e:
            print(json.dumps({
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": str(e)},
            }), flush=True)


if __name__ == "__main__":
    main()
