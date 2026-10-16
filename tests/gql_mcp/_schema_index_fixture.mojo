# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The test schema of Apollo MCP Server 2.0.0
`crates/apollo-schema-index/src/testdata/schema.graphql`."""

comptime SCHEMA = '''
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

"""A label used to categorize posts. Use createPost to assign tags."""
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
  posts(filter: PostFilter): [Post!]!
  comments(postId: ID!): [Comment!]!
  notifications(filter: NotificationFilter): [Notification!]!
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
directive @deprecated(reason: String) on FIELD_DEFINITION '''


# The paths of `snapshots/apollo_schema_index__traverse__tests__schema_traverse.snap`.
comptime TRAVERSE = """
Query
Query -> search(String) -> SearchResult
Query -> search(String) -> SearchResult -> Tag
Query -> search(String) -> SearchResult -> Tag -> posts -> Post
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> analytics -> PostAnalytics
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> analytics -> PostAnalytics -> demographics -> Demographics
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> analytics -> PostAnalytics -> demographics -> Demographics -> devices -> DeviceStats
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> analytics -> PostAnalytics -> demographics -> Demographics -> locations -> LocationStats
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> analytics -> PostAnalytics -> demographics -> Demographics -> ageGroups -> AgeGroup
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> preferences -> UserPreferences
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> preferences -> UserPreferences -> privacy -> PrivacySettings
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> preferences -> UserPreferences -> notifications -> NotificationPreferences
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> notifications -> Notification
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> notifications -> Notification -> metadata -> JSON
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> notifications -> Notification -> createdAt -> DateTime
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> notifications -> Notification -> priority -> NotificationPriority
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> comments -> Comment
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> comments -> Comment -> reactions -> Reaction
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> comments -> Comment -> reactions -> Reaction -> createdAt -> DateTime
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> comments -> Comment -> updatedAt -> DateTime
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> comments -> Comment -> createdAt -> DateTime
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> profile -> UserProfile
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> profile -> UserProfile -> location -> Location
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> profile -> UserProfile -> location -> Location -> coordinates -> Coordinates
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> profile -> UserProfile -> socialLinks -> SocialLink
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> role -> UserRole
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> updatedAt -> DateTime
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> uploader -> User -> createdAt -> DateTime
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> metadata -> MediaMetadata
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> metadata -> MediaMetadata -> dimensions -> Dimensions
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> media -> Media -> type -> MediaType
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> comments -> Comment
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> metadata -> JSON
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> author -> User
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> status -> ContentStatus
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> updatedAt -> DateTime
Query -> search(String) -> SearchResult -> Tag -> posts -> Post -> createdAt -> DateTime
Query -> search(String) -> SearchResult -> Comment
Query -> search(String) -> SearchResult -> Post
Query -> search(String) -> SearchResult -> User
Query -> notifications(NotificationFilter) -> Notification
Query -> comments(ID) -> Comment
Query -> posts(PostFilter) -> Post
Query -> post(ID) -> Post
Query -> user(ID) -> User
Query -> node(ID) -> Node
Query -> node(ID) -> Node -> Comment
Query -> node(ID) -> Node -> Post
Query -> node(ID) -> Node -> User
Query -> node(ID) -> Node -> updatedAt -> DateTime
Query -> node(ID) -> Node -> createdAt -> DateTime
Mutation
Mutation -> updateUserPreferences(ID,UserPreferencesInput) -> UserPreferences
Mutation -> uploadMedia(Upload) -> Media
Mutation -> createComment(CreateCommentInput) -> Comment
Mutation -> updatePost(ID,UpdatePostInput) -> Post
Mutation -> createPost(CreatePostInput) -> Post
Mutation -> createUser(CreateUserInput) -> User
Subscription
Subscription -> notificationReceived(ID) -> Notification
Subscription -> newComment(ID) -> Comment
Subscription -> postUpdated(ID) -> Post
"""
