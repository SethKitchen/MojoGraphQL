# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The schema and the expected text of the upstream `minify_schema` test.

Copied from Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/introspection/tools/testdata/schema.graphql`
and `introspection/snapshots/
apollo_mcp_server__introspection__minify__tests__minify_schema.snap`.
"""

comptime MINIFY_SCHEMA = """
scalar DateTime
scalar JSON
scalar Upload

enum UserRole {
  ADMIN
  MODERATOR
  USER
  GUEST
}

enum ContentStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
  DELETED
}

enum NotificationPriority {
  LOW
  MEDIUM
  HIGH
  URGENT
}

enum MediaType {
  IMAGE
  VIDEO
  AUDIO
  DOCUMENT
}

interface Node {
  id: ID!
  createdAt: DateTime!
  updatedAt: DateTime!
}

interface Content {
  id: ID!
  title: String!
  status: ContentStatus!
  author: User!
  metadata: JSON
}

type User implements Node {
  id: ID!
  createdAt: DateTime!
  updatedAt: DateTime!
  username: String!
  email: String!
  role: UserRole!
  profile: UserProfile
  posts: [Post!]!
  comments: [Comment!]!
  notifications: [Notification!]!
  preferences: UserPreferences!
}

type UserProfile {
  firstName: String
  lastName: String
  bio: String
  avatar: Media
  socialLinks: [SocialLink!]!
  location: Location
}

type Location {
  country: String!
  city: String
  coordinates: Coordinates
}

type Coordinates {
  latitude: Float!
  longitude: Float!
}

type SocialLink {
  platform: String!
  url: String!
  verified: Boolean!
}

type Post implements Node & Content {
  id: ID!
  createdAt: DateTime!
  updatedAt: DateTime!
  title: String!
  content: String!
  status: ContentStatus!
  author: User!
  metadata: JSON
  comments: [Comment!]!
  media: [Media!]!
  tags: [Tag!]!
  analytics: PostAnalytics!
}

type Comment implements Node {
  id: ID!
  createdAt: DateTime!
  updatedAt: DateTime!
  content: String!
  author: User!
  post: Post!
  parentComment: Comment
  replies: [Comment!]!
  reactions: [Reaction!]!
}

type Media {
  id: ID!
  type: MediaType!
  url: String!
  thumbnail: String
  metadata: MediaMetadata!
  uploader: User!
}

type MediaMetadata {
  size: Int!
  format: String!
  dimensions: Dimensions
  duration: Int
}

type Dimensions {
  width: Int!
  height: Int!
}

type Tag {
  id: ID!
  name: String!
  slug: String!
  description: String
  posts: [Post!]!
}

type Reaction {
  id: ID!
  type: String!
  user: User!
  comment: Comment!
  createdAt: DateTime!
}

type Notification {
  id: ID!
  type: String!
  priority: NotificationPriority!
  message: String!
  recipient: User!
  read: Boolean!
  createdAt: DateTime!
  metadata: JSON
}

type PostAnalytics {
  views: Int!
  likes: Int!
  shares: Int!
  comments: Int!
  engagement: Float!
  demographics: Demographics!
}

type Demographics {
  ageGroups: [AgeGroup!]!
  locations: [LocationStats!]!
  devices: [DeviceStats!]!
}

type AgeGroup {
  range: String!
  percentage: Float!
}

type LocationStats {
  country: String!
  count: Int!
}

type DeviceStats {
  type: String!
  count: Int!
}

type UserPreferences {
  theme: String!
  oldTheme: String @deprecated
  language: String!
  notifications: NotificationPreferences!
  privacy: PrivacySettings!
}

type NotificationPreferences {
  email: Boolean!
  push: Boolean!
  sms: Boolean!
  frequency: String!
}

type PrivacySettings {
  profileVisibility: String!
  showEmail: Boolean!
  showLocation: Boolean!
}

input CreateUserInput {
  username: String!
  email: String!
  password: String!
  role: UserRole = USER
  profile: CreateUserProfileInput
}

input CreateUserProfileInput {
  firstName: String
  lastName: String
  bio: String
  location: CreateLocationInput
}

input CreateLocationInput {
  country: String!
  city: String
  coordinates: CreateCoordinatesInput
}

input CreateCoordinatesInput {
  latitude: Float!
  longitude: Float!
}

input CreatePostInput {
  title: String!
  content: String!
  status: ContentStatus = DRAFT
  tags: [String!]
  media: [Upload!]
}

input UpdatePostInput {
  title: String
  content: String
  status: ContentStatus
  tags: [String!]
}

input CreateCommentInput {
  content: String!
  postId: ID!
  parentCommentId: ID
}

input NotificationFilter {
  priority: NotificationPriority
  read: Boolean
  type: String
  startDate: DateTime
  endDate: DateTime
}

type Query {
  node(id: ID!): Node
  user(id: ID!): User
  post(id: ID!): Post
  postsOld(filter: [ID!]) : [Post!]! @deprecated(reason: "Use posts instead")
  posts(filter: PostFilter): [Post!]!
  comments(postId: ID!): [Comment!]!
  notifications(filter: NotificationFilter): [Notification!]!
  subNotifications(filter: NotificationFilter): [[Notification!]!]!
  search(query: String!): SearchResult!
}

type Mutation {
  createUser(input: CreateUserInput!): User!
  createPost(input: CreatePostInput!): Post!
  updatePost(id: ID!, input: UpdatePostInput!): Post!
  createComment(input: CreateCommentInput!): Comment!
  deletePost(id: ID!): Boolean!
  uploadMedia(file: Upload!): Media!
  updateUserPreferences(id: ID!, preferences: UserPreferencesInput!): UserPreferences!
}

type Subscription {
  postUpdated(id: ID!): Post!
  newComment(postId: ID!): Comment!
  notificationReceived(userId: ID!): Notification!
}

union SearchResult = User | Post | Comment | Tag

input PostFilter {
  status: ContentStatus
  authorId: ID
  tags: [String!]
  dateRange: DateRangeInput
}

input DateRangeInput {
  start: DateTime!
  end: DateTime!
}

input UserPreferencesInput {
  theme: String
  language: String
  notifications: NotificationPreferencesInput
  privacy: PrivacySettingsInput
}

input NotificationPreferencesInput {
  email: Boolean
  push: Boolean
  sms: Boolean
  frequency: String
}

input PrivacySettingsInput {
  profileVisibility: String
  showEmail: Boolean
  showLocation: Boolean
}

directive @auth(requires: UserRole!) on FIELD_DEFINITION
directive @cache(ttl: Int!) on FIELD_DEFINITION
directive @deprecated(reason: String) on FIELD_DEFINITION """
"""The schema of the upstream minify tests."""

comptime MINIFY_EXPECTED = """
__Schema: T:"A GraphQL Schema defines the capabilities of a GraphQL server. It exposes all available types and directives on the server, as well as the entry points for query, mutation, and subscription operations."__Schema:description:s,"A list of all types supported by this server."types:[__Type!]!,"The type that query operations will be rooted at."queryType:__Type!,"If this server supports mutation, the type that mutation operations will be rooted at."mutationType:__Type,"If this server support subscription, the type that subscription operations will be rooted at."subscriptionType:__Type,"A list of all directives supported by this server."directives:[__Directive!]!
__Type: T:"The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum. Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByURL`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types."__Type:kind:__TypeKind!,name:s,description:s,fields(includeDeprecated:b!):[__Field!],interfaces:[__Type!],possibleTypes:[__Type!],enumValues(includeDeprecated:b!):[__EnumValue!],inputFields(includeDeprecated:b!):[__InputValue!],ofType:__Type,specifiedByURL:s,isOneOf:b
__TypeKind: E:"An enum describing what kind of type a given `__Type` is."__TypeKind:SCALAR,OBJECT,INTERFACE,UNION,ENUM,INPUT_OBJECT,LIST,NON_NULL
__Field: T:"Object and Interface types are described by a list of Fields, each of which has a name, potentially a list of arguments, and a return type."__Field:name:s!,description:s,args(includeDeprecated:b!):[__InputValue!]!,type:__Type!,isDeprecated:b!,deprecationReason:s
__InputValue: T:"Arguments provided to Fields or Directives and the input fields of an InputObject are represented as Input Values which describe their type and optionally a default value."__InputValue:name:s!,description:s,type:__Type!,"A GraphQL-formatted string representing the default value for this input value."defaultValue:s,isDeprecated:b!,deprecationReason:s
__EnumValue: T:"One possible value for a given Enum. Enum values are unique values, not a placeholder for a string or numeric value. However an Enum value is returned in a JSON response as a string."__EnumValue:name:s!,description:s,isDeprecated:b!,deprecationReason:s
__Directive: T:"A Directive provides a way to describe alternate runtime execution and type validation behavior in a GraphQL document. In some cases, you need to provide options to alter GraphQL's execution behavior in ways field arguments will not suffice, such as conditionally including or skipping a field. Directives provide this by describing additional information to the executor."__Directive:name:s!,description:s,locations:[__DirectiveLocation!]!,args(includeDeprecated:b!):[__InputValue!]!,isRepeatable:b!
__DirectiveLocation: E:"A Directive can be adjacent to many parts of the GraphQL language, a __DirectiveLocation describes one such possible adjacencies."__DirectiveLocation:QUERY,MUTATION,SUBSCRIPTION,FIELD,FRAGMENT_DEFINITION,FRAGMENT_SPREAD,INLINE_FRAGMENT,VARIABLE_DEFINITION,SCHEMA,SCALAR,OBJECT,FIELD_DEFINITION,ARGUMENT_DEFINITION,INTERFACE,UNION,ENUM,ENUM_VALUE,INPUT_OBJECT,INPUT_FIELD_DEFINITION
Int: i
Float: f
String: s
Boolean: b
ID: d
DateTime: DateTime
JSON: JSON
Upload: Upload
UserRole: E:UserRole:ADMIN,MODERATOR,USER,GUEST
ContentStatus: E:ContentStatus:DRAFT,PUBLISHED,ARCHIVED,DELETED
NotificationPriority: E:NotificationPriority:LOW,MEDIUM,HIGH,URGENT
MediaType: E:MediaType:IMAGE,VIDEO,AUDIO,DOCUMENT
Node: F:Node:id:d!,createdAt:DateTime!,updatedAt:DateTime!
Content: F:Content:id:d!,title:s!,status:ContentStatus!,author:User!,metadata:JSON
User: T:User<Node>:id:d!,createdAt:DateTime!,updatedAt:DateTime!,username:s!,email:s!,role:UserRole!,profile:UserProfile,posts:[Post!]!,comments:[Comment!]!,notifications:[Notification!]!,preferences:UserPreferences!
UserProfile: T:UserProfile:firstName:s,lastName:s,bio:s,avatar:Media,socialLinks:[SocialLink!]!,location:Location
Location: T:Location:country:s!,city:s,coordinates:Coordinates
Coordinates: T:Coordinates:latitude:f!,longitude:f!
SocialLink: T:SocialLink:platform:s!,url:s!,verified:b!
Post: T:Post<Node,Content>:id:d!,createdAt:DateTime!,updatedAt:DateTime!,title:s!,content:s!,status:ContentStatus!,author:User!,metadata:JSON,comments:[Comment!]!,media:[Media!]!,tags:[Tag!]!,analytics:PostAnalytics!
Comment: T:Comment<Node>:id:d!,createdAt:DateTime!,updatedAt:DateTime!,content:s!,author:User!,post:Post!,parentComment:Comment,replies:[Comment!]!,reactions:[Reaction!]!
Media: T:Media:id:d!,type:MediaType!,url:s!,thumbnail:s,metadata:MediaMetadata!,uploader:User!
MediaMetadata: T:MediaMetadata:size:i!,format:s!,dimensions:Dimensions,duration:i
Dimensions: T:Dimensions:width:i!,height:i!
Tag: T:Tag:id:d!,name:s!,slug:s!,description:s,posts:[Post!]!
Reaction: T:Reaction:id:d!,type:s!,user:User!,comment:Comment!,createdAt:DateTime!
Notification: T:Notification:id:d!,type:s!,priority:NotificationPriority!,message:s!,recipient:User!,read:b!,createdAt:DateTime!,metadata:JSON
PostAnalytics: T:PostAnalytics:views:i!,likes:i!,shares:i!,comments:i!,engagement:f!,demographics:Demographics!
Demographics: T:Demographics:ageGroups:[AgeGroup!]!,locations:[LocationStats!]!,devices:[DeviceStats!]!
AgeGroup: T:AgeGroup:range:s!,percentage:f!
LocationStats: T:LocationStats:country:s!,count:i!
DeviceStats: T:DeviceStats:type:s!,count:i!
UserPreferences: T:UserPreferences:theme:s!,oldTheme:s@D,language:s!,notifications:NotificationPreferences!,privacy:PrivacySettings!
NotificationPreferences: T:NotificationPreferences:email:b!,push:b!,sms:b!,frequency:s!
PrivacySettings: T:PrivacySettings:profileVisibility:s!,showEmail:b!,showLocation:b!
CreateUserInput: I:CreateUserInput:username:s!,email:s!,password:s!,role:UserRole,profile:CreateUserProfileInput
CreateUserProfileInput: I:CreateUserProfileInput:firstName:s,lastName:s,bio:s,location:CreateLocationInput
CreateLocationInput: I:CreateLocationInput:country:s!,city:s,coordinates:CreateCoordinatesInput
CreateCoordinatesInput: I:CreateCoordinatesInput:latitude:f!,longitude:f!
CreatePostInput: I:CreatePostInput:title:s!,content:s!,status:ContentStatus,tags:[s!],media:[Upload!]
UpdatePostInput: I:UpdatePostInput:title:s,content:s,status:ContentStatus,tags:[s!]
CreateCommentInput: I:CreateCommentInput:content:s!,postId:d!,parentCommentId:d
NotificationFilter: I:NotificationFilter:priority:NotificationPriority,read:b,type:s,startDate:DateTime,endDate:DateTime
Query: T:Query:node(id:d!):Node,user(id:d!):User,post(id:d!):Post,postsOld(filter:[d!]):[Post!]!@D("Use posts instead"),posts(filter:PostFilter):[Post!]!,comments(postId:d!):[Comment!]!,notifications(filter:NotificationFilter):[Notification!]!,subNotifications(filter:NotificationFilter):[[Notification!]!]!,search(query:s!):SearchResult!
Mutation: T:Mutation:createUser(input:CreateUserInput!):User!,createPost(input:CreatePostInput!):Post!,updatePost(id:d!,input:UpdatePostInput!):Post!,createComment(input:CreateCommentInput!):Comment!,deletePost(id:d!):b!,uploadMedia(file:Upload!):Media!,updateUserPreferences(id:d!,preferences:UserPreferencesInput!):UserPreferences!
Subscription: T:Subscription:postUpdated(id:d!):Post!,newComment(postId:d!):Comment!,notificationReceived(userId:d!):Notification!
SearchResult: U:SearchResult:User,Post,Comment,Tag
PostFilter: I:PostFilter:status:ContentStatus,authorId:d,tags:[s!],dateRange:DateRangeInput
DateRangeInput: I:DateRangeInput:start:DateTime!,end:DateTime!
UserPreferencesInput: I:UserPreferencesInput:theme:s,language:s,notifications:NotificationPreferencesInput,privacy:PrivacySettingsInput
NotificationPreferencesInput: I:NotificationPreferencesInput:email:b,push:b,sms:b,frequency:s
PrivacySettingsInput: I:PrivacySettingsInput:profileVisibility:s,showEmail:b,showLocation:b
"""
"""The upstream snapshot: one `name: minified` line per type."""
