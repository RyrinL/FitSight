import os
from crewai import Agent, Task, Crew, Process, LLM

groq_llm = LLM(
    model="groq/llama-3.3-70b-versatile",
    api_key=os.environ.get("GROQ_API_KEY"),
    temperature=0.2,
)

# --- Agents ---

swift_architect = Agent(
    role="Swift iOS Architect",
    goal="Review and improve Swift code quality for the FitSight fitness app",
    backstory=(
        "Expert iOS developer specializing in SwiftUI, Swift Concurrency, "
        "and fitness app architecture. Focused on clean, performant code."
    ),
    llm=groq_llm,
    verbose=True,
)

healthkit_agent = Agent(
    role="HealthKit Integration Specialist",
    goal="Ensure correct, privacy-safe HealthKit integration in the FitSight app",
    backstory=(
        "Apple platform engineer with deep expertise in HealthKit, HKWorkoutSession, "
        "HKStatisticsQuery, and HealthKit permissions. Knows every pitfall around "
        "background delivery, entitlements, and data privacy requirements for health apps."
    ),
    llm=groq_llm,
    verbose=True,
)

qa_agent = Agent(
    role="iOS QA Engineer",
    goal="Identify bugs, edge cases, and test gaps in the FitSight fitness app",
    backstory=(
        "Senior QA engineer specializing in iOS apps. Expert in XCTest, Swift Testing, "
        "UI testing, and writing test plans that cover happy path, edge cases, "
        "offline behavior, and HealthKit permission denial scenarios."
    ),
    llm=groq_llm,
    verbose=True,
)

ui_agent = Agent(
    role="SwiftUI UI Specialist",
    goal="Review and improve SwiftUI views for the FitSight fitness app",
    backstory=(
        "SwiftUI expert focused on accessibility, animation, layout performance, "
        "and Apple HIG compliance. Catches common SwiftUI pitfalls like unnecessary "
        "redraws, missing accessibility labels, and poor dark-mode support."
    ),
    llm=groq_llm,
    verbose=True,
)

fitness_ux_agent = Agent(
    role="Fitness UX Specialist",
    goal="Ensure fitness features follow best UX practices for health apps",
    backstory=(
        "UX designer with deep knowledge of Apple Human Interface Guidelines "
        "and fitness/health app patterns. Prioritizes user motivation and clarity."
    ),
    llm=groq_llm,
    verbose=True,
)

# --- Tasks ---

code_review_task = Task(
    description=(
        "Review the provided Swift code for: "
        "1) Swift Concurrency best practices "
        "2) Architecture and code quality "
        "Code to review: {code}"
    ),
    expected_output="Detailed code review with specific improvement suggestions",
    agent=swift_architect,
)

healthkit_review_task = Task(
    description=(
        "Review the provided code or feature for HealthKit concerns: "
        "1) Correct usage of HKWorkoutSession, HKStatisticsQuery, HKSampleQuery "
        "2) Permission request timing and privacy strings "
        "3) Background delivery and entitlements "
        "4) Data privacy best practices "
        "Code or feature: {code}"
    ),
    expected_output="HealthKit review with issues found and recommended fixes",
    agent=healthkit_agent,
)

qa_task = Task(
    description=(
        "Write a test plan and identify edge cases for the feature: {feature}. "
        "Cover: happy path, error states, HealthKit permission denied, "
        "offline mode, and any data boundary conditions."
    ),
    expected_output="Test plan with XCTest/Swift Testing code snippets for key scenarios",
    agent=qa_agent,
)

ui_review_task = Task(
    description=(
        "Review the SwiftUI code or screen description for: "
        "1) Accessibility (labels, traits, Dynamic Type) "
        "2) Dark mode and color correctness "
        "3) Layout performance and unnecessary redraws "
        "4) HIG compliance "
        "Input: {feature}"
    ),
    expected_output="UI review with specific SwiftUI fixes and accessibility improvements",
    agent=ui_agent,
)

ux_review_task = Task(
    description=(
        "Review the fitness feature described: {feature}. "
        "Check against Apple HIG and fitness app best practices."
    ),
    expected_output="UX recommendations with rationale",
    agent=fitness_ux_agent,
)

fitness_crew = Crew(
    agents=[swift_architect, healthkit_agent, qa_agent, ui_agent, fitness_ux_agent],
    tasks=[code_review_task, healthkit_review_task, qa_task, ui_review_task, ux_review_task],
    process=Process.sequential,
    verbose=True,
)


if __name__ == "__main__":
    result = fitness_crew.kickoff(inputs={
        "code": "// paste Swift code here",
        "feature": "workout tracking screen",
    })
    print(result)
