# Asteroidea - Social Fitness App Roadmap

## Project Overview
A social app for creating and joining running/cycling events with real-time features, location services, and community interaction.

**Tech Stack:** Flutter + Firebase  
**Target Users:** Runners and cyclists looking to connect and organize group activities

---

## 🎯 Core Features Specification

### 1. Event Management System

#### Event Creation & Joining
- [x] **Basic event creation** (name, date, time, location, distance, pace)
- [x] **Event editing/deletion** with user confirmation
- [x] **Group size limits** (optional, display on event cards)
- [ ] **Friend invitation system**
  - Search by name/phone number
  - Invite via SMS with app link
  - In-app notification system for invites
  - Accept/decline invitation flow
- [ ] **Public event joining** (one-click join for public events)
- [ ] **Event capacity management** (prevent over-capacity joins)

#### Event Discovery & Display
- [x] **Basic event filtering** (running/cycling, upcoming/hosting/open)
- [ ] **Advanced filtering**
  - Location/zip code search
  - Date range selection
  - Skill level filtering
  - Distance preferences
- [ ] **Event detail page** (modal with X to close)
- [ ] **Participant count & profile pictures** (show 5 + overflow indicator)
- [ ] **Map integration** for location-based discovery

### 2. Social Features

#### User Connections
- [ ] **Friend/follow system**
  - Send/accept friend requests
  - View friends' public events
  - Friend activity feed
- [ ] **Event recommendations** based on preferences and social graph
- [ ] **User search** (by name, username, phone)

#### Communication & Engagement
- [ ] **Event commenting system**
  - Text comments with timestamps
  - Emoji reactions (preset options)
  - Real-time updates
  - Infinite scroll for long comment threads
- [ ] **Post-event features**
  - Photo sharing
  - Event reviews/ratings
  - Stats sharing
  - Achievement tracking
- [ ] **Notification system**
  - Friend creates new event
  - Event invitations
  - Event updates/comments
  - Push notification infrastructure

### 3. Location & Tracking

#### Core Location Services
- [ ] **Meeting point display** (current implementation)
- [ ] **Zip code/area search** for event discovery
- [ ] **Map view** for events in area
- [ ] **GPS tracking opt-in** (button to start/stop sharing location)

#### Cost Optimization Strategy
- **Prioritize Google Maps usage:**
  1. Event detail view (single location pin)
  2. Area discovery (when user explicitly searches)
  3. Avoid: Real-time tracking, route mapping (use alternative APIs)
- **Alternative solutions:**
  - OpenStreetMap for basic mapping
  - Device GPS for tracking (store locally, sync periodically)
  - Geocoding only for zip code → approximate coordinates

### 4. Performance & Scalability

#### Database Optimization
- [x] **Event creator name denormalization** (avoid N+1 queries)
- [ ] **Pagination implementation**
  - Event lists (infinite scroll)
  - Comment threads
  - Friend lists
- [ ] **Efficient querying strategies**
  - Composite indexes for filtered searches
  - Geographic queries optimization
  - Cache frequently accessed data

#### Cost Management
- [ ] **Firebase usage optimization**
  - Minimize real-time listeners
  - Batch operations where possible
  - Implement pagination to reduce read costs
- [ ] **Image optimization**
  - Compress profile photos
  - Progressive loading
  - CDN implementation

---

## 🚀 Implementation Strategy

### Phase 1: Core Event Features (Weeks 1-3)
**Goal:** Complete basic event lifecycle with social joining

#### Week 1: Event Joining System
- [ ] Design event detail modal/page
- [ ] Implement join/leave event functionality
- [ ] Add participant count and basic participant display
- [ ] Update event cards to show current participant count

#### Week 2: Invitation System
- [ ] Create friend search functionality
- [ ] Implement SMS invitation system
- [ ] Build in-app notification system
- [ ] Design and implement invite acceptance flow

#### Week 3: Event Discovery Enhancement
- [ ] Add location-based filtering
- [ ] Implement date range filtering
- [ ] Basic map integration for event discovery
- [ ] Performance optimization for event queries

### Phase 2: Social Infrastructure (Weeks 4-6)

#### Week 4: Friend System
- [ ] Design friend/follow data model
- [ ] Implement friend request system
- [ ] Create friend management UI
- [ ] Add friend activity visibility

#### Week 5: Communication Features
- [ ] Build event commenting system
- [ ] Implement emoji reactions
- [ ] Add real-time comment updates
- [ ] Design notification system architecture

#### Week 6: Content & Engagement
- [ ] Photo sharing for events
- [ ] Post-event features (reviews, stats)
- [ ] Push notification implementation
- [ ] Social recommendation algorithm

### Phase 3: Advanced Features & Polish (Weeks 7-9)

#### Week 7: Location Services
- [ ] GPS tracking opt-in system
- [ ] Map view for event discovery
- [ ] Location search optimization
- [ ] Cost optimization implementation

#### Week 8: Performance & Scalability
- [ ] Implement infinite scroll for all lists
- [ ] Database query optimization
- [ ] Image and asset optimization
- [ ] Error handling and offline messaging

#### Week 9: Testing & Launch Prep
- [ ] Comprehensive testing across features
- [ ] Performance testing with simulated load
- [ ] Security audit
- [ ] App store preparation

---

## 📊 Technical Priorities

### Immediate (Phase 1)
1. **Event joining/leaving functionality**
2. **Participant count and display**
3. **Basic invitation system**
4. **Event detail modal/page**

### Short-term (Phase 2)
1. **Friend/follow system**
2. **Commenting and reactions**
3. **Push notifications**
4. **Location-based discovery**

### Long-term (Phase 3)
1. **GPS tracking features**
2. **Advanced filtering and search**
3. **Performance optimization**
4. **Social recommendations**

---

## 🎨 UI/UX Considerations

### Design Consistency
- [x] **Unified design system** (shadcn/ui components)
- [ ] **Consistent modal patterns** for event details
- [ ] **Loading states** for all async operations
- [ ] **Error states** with clear messaging

### Mobile-First Design
- [ ] **Touch-friendly interactions** (proper button sizes)
- [ ] **Efficient navigation** (bottom tabs, modals)
- [ ] **Optimized for one-handed use**
- [ ] **Dark mode support** (future consideration)

---

## 📈 Success Metrics

### User Engagement
- Event creation rate
- Event join rate
- Comment/reaction frequency
- Friend connection growth

### Technical Performance
- App load time < 3 seconds
- Event discovery response < 2 seconds
- 99.9% uptime
- Firebase cost per active user

### Business Metrics
- Monthly active users
- Event completion rate
- User retention (7-day, 30-day)
- Viral coefficient (invitations sent/accepted)

---

## 🔄 Feedback & Iteration Plan

### Weekly Reviews
- Feature completion assessment
- User feedback collection (beta testers)
- Performance monitoring
- Cost analysis and optimization

### Key Decision Points
1. **Week 3:** Evaluate location service costs and usage patterns
2. **Week 6:** Assess social feature adoption and engagement
3. **Week 9:** Launch readiness and scaling preparation

---

*Last Updated: [Current Date]*  
*Next Review: [Date + 1 week]*