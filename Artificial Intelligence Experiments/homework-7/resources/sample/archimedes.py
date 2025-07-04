import getpass
import os

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import tool
from langgraph.graph import MessagesState, StateGraph, START
from langgraph.prebuilt import ToolNode, tools_condition


# Set environment variables if not already set.
def _set_env(var: str):
    if not os.environ.get(var):
        os.environ[var] = getpass.getpass(f"Enter value for {var}: ")


# API keys for Anthropic.
_set_env("GOOGLE_API_KEY")
# API keys for LangSmith.
_set_env("LANGSMITH_API_KEY")

# Use LangSmith for tracing.
os.environ["LANGSMITH_TRACE"] = "true"
os.environ["LANGSMITH_PROJECT"] = "sysu-ai-lab7"


# Tool
@tool
def add(a: int, b: int) -> int:
    """
    Add a and b.

    Args:
        a (int): first integer
        b (int): second integer
    """
    return a + b


@tool
def sub(a: int, b: int) -> int:
    """
    Subtract a by b.

    Args:
        a (int): first integer
        b (int): second integer
    """
    return a - b


@tool
def mul(a: int, b: int) -> int:
    """
    Multiply a and b.

    Args:
        a (int): first integer
        b (int): second integer
    """
    return a * b


@tool
def div(a: int, b: int) -> float:
    """
    Divide a by b.

    Args:
        a (int): first integer
        b (int): second integer
    """
    return a / b


# Initialize the LLM.
llm = ChatGoogleGenerativeAI(model="gemini-2.0-flash")
llm_with_tools = llm.bind_tools([add, sub, mul, div])

# Generate system message.
sys_msg = SystemMessage(content="You are a helpful assistant tasked with performing arithmetic on a set of inputs.")


# Node
def assistant(state: MessagesState):
    return {"messages": [llm_with_tools.invoke([sys_msg] + state["messages"])]}


# Init graph.
graph = StateGraph(MessagesState)
# Draw nodes.
graph.add_node("assistant", assistant)
graph.add_node("tools", ToolNode([add, sub, mul, div]))
# Draw edges.
graph.add_edge(START, "assistant")
graph.add_conditional_edges("assistant", tools_condition)
graph.add_edge("tools", "assistant")
# Compile graph.
react_graph = graph.compile()

# Run with a prompt.
prompt = input("Prompt the bot to perform arithmetic operations: ")
messages = [HumanMessage(content=prompt)]
messages = react_graph.invoke({"messages": messages})

# Print the process.
for m in messages["messages"]:
    m.pretty_print()
