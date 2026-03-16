public inherited sharing class DevMcpHarnessServerFactory {
    public static final String SECRET_RESOURCE_URI = 'mcp://harness/secret/one';
    public static final String TEMPLATE_URI = 'mcp://harness/templates/profile-summary{?value}';
    public static final String TEMPLATE_NAME = 'profile-summary';
    public static final String PROMPT_NAME = 'review-profile';

    public static McpServer build() {
        McpToolDefinition sumTool = new McpToolDefinition('math.sum', 'Adds two integers.', SumArguments.class);
        sumTool.inputSchema = new Map<String, Object>{
            'type' => 'object',
            'additionalProperties' => false,
            'properties' => new Map<String, Object>{
                'a' => new Map<String, Object>{ 'type' => 'integer' },
                'b' => new Map<String, Object>{ 'type' => 'integer' }
            },
            'required' => new List<Object>{ 'a', 'b' }
        };
        sumTool.annotations = buildReadOnlyAnnotations();

        McpToolDefinition profileSumTool = new McpToolDefinition(
            'math.profile_sum',
            'Sums nested profile weights and a top-level bonus value.',
            ProfileSumArguments.class
        );
        profileSumTool.inputSchema = new Map<String, Object>{
            'type' => 'object',
            'additionalProperties' => false,
            'properties' => new Map<String, Object>{
                'profile' => new Map<String, Object>{
                    'type' => 'object',
                    'additionalProperties' => false,
                    'properties' => new Map<String, Object>{
                        'user' => new Map<String, Object>{
                            'type' => 'object',
                            'additionalProperties' => false,
                            'properties' => new Map<String, Object>{
                                'id' => new Map<String, Object>{ 'type' => 'string' },
                                'weights' => new Map<String, Object>{
                                    'type' => 'object',
                                    'additionalProperties' => false,
                                    'properties' => new Map<String, Object>{
                                        'primary' => new Map<String, Object>{ 'type' => 'integer' },
                                        'secondary' => new Map<String, Object>{ 'type' => 'integer' }
                                    },
                                    'required' => new List<Object>{ 'primary', 'secondary' }
                                }
                            },
                            'required' => new List<Object>{ 'id', 'weights' }
                        },
                        'metadata' => new Map<String, Object>{
                            'type' => 'object',
                            'additionalProperties' => false,
                            'properties' => new Map<String, Object>{
                                'label' => new Map<String, Object>{ 'type' => 'string' }
                            },
                            'required' => new List<Object>{ 'label' }
                        }
                    },
                    'required' => new List<Object>{ 'user', 'metadata' }
                },
                'bonus' => new Map<String, Object>{ 'type' => 'integer' }
            },
            'required' => new List<Object>{ 'profile', 'bonus' }
        };
        profileSumTool.annotations = buildReadOnlyAnnotations();

        McpResourceDefinition resourceDef = new McpResourceDefinition(SECRET_RESOURCE_URI, 'Harness Secret One');
        resourceDef.description = 'Returns a fixed integer payload used by the harness.';
        resourceDef.mimeType = 'application/json';

        McpResourceTemplateDefinition templateDef = new McpResourceTemplateDefinition(
            TEMPLATE_NAME,
            TEMPLATE_URI,
            TemplateArguments.class
        );
        templateDef.description = 'Adds the provided integer to the fixed harness secret.';

        McpPromptDefinition promptDef = new McpPromptDefinition(PROMPT_NAME, 'Builds a short review prompt for a named target.', PromptArguments.class);
        promptDef.arguments = new List<McpPromptArgumentDefinition>{
            new McpPromptArgumentDefinition('target', 'Profile target to review.', true)
        };

        return new McpServer('Salesforce MCP Harness', '1.0.0')
            .registerTool(sumTool, new SumTool())
            .registerTool(profileSumTool, new ProfileSumTool())
            .registerResource(resourceDef, new SecretResource())
            .registerResourceTemplate(templateDef, new SecretTemplate())
            .registerPrompt(promptDef, new ReviewPrompt());
    }

    private static McpToolAnnotations buildReadOnlyAnnotations() {
        McpToolAnnotations annotations = new McpToolAnnotations();
        annotations.readOnlyHint = true;
        annotations.idempotentHint = true;
        annotations.openWorldHint = false;
        return annotations;
    }

    public class SumTool implements McpToolExecutor {
        public McpToolResult execute(JsonRpcParamsBase arguments, McpRequestContext context) {
            SumArguments typed = (SumArguments) arguments;

            McpToolResult result = new McpToolResult();
            result.content.add(new McpTextContent(String.valueOf(typed.a + typed.b)));
            return result;
        }
    }

    public class ProfileSumTool implements McpToolExecutor {
        public McpToolResult execute(JsonRpcParamsBase arguments, McpRequestContext context) {
            ProfileSumArguments typed = (ProfileSumArguments) arguments;
            Integer total = typed.profile.user.weights.primary + typed.profile.user.weights.secondary + typed.bonus;
            String summary = typed.profile.user.id + '|' + typed.profile.metadata.label + '|' + String.valueOf(total);

            McpToolResult result = new McpToolResult();
            result.content.add(new McpTextContent(summary));
            return result;
        }
    }

    public class SecretResource implements McpResourceExecutor {
        public McpResourceResult read(String resourceUri, McpRequestContext context) {
            McpResourceResult result = new McpResourceResult();
            result.contents.add(new McpResourceContentItem(resourceUri, '{"value":1}', 'application/json'));
            return result;
        }
    }

    public class SecretTemplate implements McpResourceTemplateExecutor {
        public McpResourceResult resolve(JsonRpcParamsBase arguments, McpRequestContext context) {
            TemplateArguments typed = (TemplateArguments) arguments;

            McpResourceResult result = new McpResourceResult();
            result.contents.add(
                new McpResourceContentItem(
                    'mcp://harness/templates/profile-summary',
                    '{"value":' + String.valueOf(typed.value + 1) + '}',
                    'application/json'
                )
            );
            return result;
        }
    }

    public class ReviewPrompt implements McpPromptExecutor {
        public McpPromptResult resolve(JsonRpcParamsBase arguments, McpRequestContext context) {
            PromptArguments typed = (PromptArguments) arguments;

            McpPromptResult result = new McpPromptResult();
            result.description = 'Harness prompt for ' + typed.target + '.';
            result.messages.add(McpPromptMessage.userText('Review profile for ' + typed.target + ' using the harness outputs.'));
            return result;
        }
    }

    public class SumArguments extends JsonRpcParamsBase {
        public Integer a;
        public Integer b;

        public override void validate() {
            if (this.a == null || this.b == null) {
                throw new McpExceptions.InvalidParamsException('math.sum requires integer a and b.');
            }
        }
    }

    public class ProfileSumArguments extends JsonRpcParamsBase {
        public Profile profile;
        public Integer bonus;

        public override void validate() {
            if (this.profile == null) {
                throw new McpExceptions.InvalidParamsException('math.profile_sum requires profile.');
            }
            this.profile.validate();
            if (this.bonus == null) {
                throw new McpExceptions.InvalidParamsException('math.profile_sum requires integer bonus.');
            }
        }
    }

    public class Profile {
        public ProfileUser user;
        public ProfileMetadata metadata;

        public void validate() {
            if (this.user == null) {
                throw new McpExceptions.InvalidParamsException('math.profile_sum requires profile.user.');
            }
            this.user.validate();
            if (this.metadata == null) {
                throw new McpExceptions.InvalidParamsException('math.profile_sum requires profile.metadata.');
            }
            this.metadata.validate();
        }
    }

    public class ProfileUser {
        public String id;
        public ProfileWeights weights;

        public void validate() {
            if (String.isBlank(this.id)) {
                throw new McpExceptions.InvalidParamsException('math.profile_sum requires profile.user.id.');
            }
            if (this.weights == null) {
                throw new McpExceptions.InvalidParamsException('math.profile_sum requires profile.user.weights.');
            }
            this.weights.validate();
        }
    }

    public class ProfileWeights {
        public Integer primary;
        public Integer secondary;

        public void validate() {
            if (this.primary == null || this.secondary == null) {
                throw new McpExceptions.InvalidParamsException('math.profile_sum requires profile.user.weights.primary and secondary.');
            }
        }
    }

    public class ProfileMetadata {
        public String label;

        public void validate() {
            if (String.isBlank(this.label)) {
                throw new McpExceptions.InvalidParamsException('math.profile_sum requires profile.metadata.label.');
            }
        }
    }

    public class TemplateArguments extends JsonRpcParamsBase {
        public Integer value;

        public override void validate() {
            if (this.value == null) {
                throw new McpExceptions.InvalidParamsException(TEMPLATE_NAME + ' requires integer value.');
            }
        }
    }

    public class PromptArguments extends JsonRpcParamsBase {
        public String target;

        public override void validate() {
            if (String.isBlank(this.target)) {
                throw new McpExceptions.InvalidParamsException(PROMPT_NAME + ' requires non-empty target.');
            }
        }
    }
}
