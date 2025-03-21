//
//  RegretStore.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

class RegretStore: ObservableObject {
    static let shared = RegretStore()
    
    @Published var regrets: [Regret] {
        didSet {
            saveRegrets()
        }
    }
    @Published var selectedRegret: Regret?
    @Published var currentRegretIndex: Int = 0
    
    public init() {
        if let data = UserDefaults.standard.data(forKey: "SavedRegrets"),
           let savedRegrets = try? JSONDecoder().decode([Regret].self, from: data) {
            self.regrets = savedRegrets
        } else {
            self.regrets = []
            // Add initial sample data only if first launch
            addRegrets([
                
                Regret(
                    regretPrompt: "What is the ISO OSI reference model?",
                    regret: "A conceptual framework that describes the functions of a networking system by dividing it into a set of seven distinct layers.",
                    choices: [
                        "A physical piece of networking hardware.",
                        "A conceptual framework that describes the functions of a networking system by dividing it into a set of seven distinct layers.",
                        "A software application for sending emails.",
                        "A specific network protocol used on the internet."
                    ],
                    correctAnswerIndex: 1,
                    backgroundExplanation: "The ISO OSI model is not a physical thing or a specific protocol, but rather a way to understand and organize the different processes needed for network communication. The 'ISO' part refers to the International Organization for Standardization, and 'OSI' stands for Open Systems Interconnection. The model breaks down the complex task of networking into smaller, more manageable layers, each with specific responsibilities [1, 2]."
                ),
                Regret(
                    regretPrompt: "Why was the ISO OSI model proposed?",
                    regret: "To enable interoperability between networks built with proprietary protocols from different vendors.",
                    choices: [
                        "To reduce the cost of networking hardware.",
                        "To enable interoperability between networks built with proprietary protocols from different vendors.",
                        "To centralize network control.",
                        "To make networks faster."
                    ],
                    correctAnswerIndex: 1,
                    backgroundExplanation: "In the past, networks were often built using specific technologies and protocols from a single company. This meant that networks from different vendors couldn't easily communicate with each other. The OSI model aimed to create a common set of standards so that equipment and networks could work together seamlessly [2, 3]."
                ),
                Regret(
                    regretPrompt: "What does the acronym 'ISO' in the ISO OSI model refer to?",
                    regret: "The International Organization for Standardization, which chose this name to avoid language-specific acronyms [4].",
                    choices: [
                        "Integrated Services Organization.",
                        "International Systems Operation.",
                        "International Organization for Standardization.",
                        "Internet Standards Organization."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "Contrary to common belief, 'ISO' is not an acronym for 'International Standards Organization'. The ISO itself is an international standards body with national standards bodies as members. It chose 'ISO' based on the Greek word 'ἶσος' meaning 'the same', so its name would be consistent across all languages [4, 5]."
                ),
                Regret(
                    regretPrompt: "What is the general purpose of a standard in the context of networking?",
                    regret: "To ensure that products and processes that follow the standard are compatible with one another [4].",
                    choices: [
                        "To force everyone to use the same software.",
                        "To limit innovation in technology.",
                        "To ensure that products and processes that follow the standard are compatible with one another.",
                        "To make products more expensive."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "A standard provides a set of rules or guidelines that different manufacturers and developers can follow. This ensures that their products or systems can work together effectively. The attraction of standards in networking is that they promise interoperability [4, 6]."
                ),
                Regret(
                    regretPrompt: "What is a protocol in data communications?",
                    regret: "A detailed description of the rules to be followed when communicating [7, 8].",
                    choices: [
                        "A software application used for browsing the internet.",
                        "A detailed description of the rules to be followed when communicating.",
                        "A specific piece of hardware that connects networks.",
                        "A type of physical cable used for networking."
                    ],
                    correctAnswerIndex: 1,
                    backgroundExplanation: "Think of a protocol as a set of agreed-upon conventions. Just like there are protocols in diplomatic relations that dictate how to address heads of state [7], in data communications, a protocol specifies everything from how a message is formatted to how errors are handled. Different layers of the network model have their own specific protocols [8, 9]."
                ),
                Regret(
                    regretPrompt: "What is a protocol stack?",
                    regret: "The layered network software, where each layer has its own protocol(s) [9].",
                    choices: [
                        "A single, large program that handles all networking tasks.",
                        "A central server that manages all network communication.",
                        "The layered network software, where each layer has its own protocol(s).",
                        "A physical stack of networking cables."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "Since network functionality is divided into layers, each layer needs its own set of rules (protocols) to govern how it operates and communicates with the layers above and below it. The collection of these protocols, working together in a layered fashion, is often referred to as the protocol stack [9]."
                ),
                Regret(
                    regretPrompt: "Did the original goal of the ISO OSI model to have networks fully implement its protocols succeed in practice?",
                    regret: "No, the TCP/IP suite of protocols became more widely deployed [9, 10].",
                    choices: [
                        "It is still an ongoing process with increasing adoption.",
                        "No, the TCP/IP suite of protocols became more widely deployed.",
                        "Yes, most networks today are fully OSI compliant.",
                        "Partially, some aspects were adopted, but not others."
                    ],
                    correctAnswerIndex: 1,
                    backgroundExplanation: "While the ISO OSI model serves as an excellent educational tool for understanding networking concepts, the actual protocols specified by the OSI model were not widely implemented in real-world networks. The TCP/IP protocol suite, which was developed around the same time, gained practical traction and became the foundation of the internet [10]."
                ),
                Regret(
                    regretPrompt: "What is the main value of the ISO OSI model today?",
                    regret: "It serves as an excellent model for understanding networking and its terminology is widely used [10, 11].",
                    choices: [
                        "It is a software package that can be installed to manage networks.",
                        "It serves as an excellent model for understanding networking and its terminology is widely used.",
                        "It has been completely replaced by newer models and is no longer relevant.",
                        "It is the primary standard used for building all modern networks."
                    ],
                    correctAnswerIndex: 1,
                    backgroundExplanation: "Even though networks don't strictly adhere to the OSI protocols, the model provides a clear and organized way to think about the different functions involved in network communication. The terminology associated with the OSI layers (like 'application layer', 'network layer', etc.) is commonly used by network specialists, even when discussing TCP/IP [11]."
                ),
                Regret(
                    regretPrompt: "How many layers are there in the ISO OSI model?",
                    regret: "There are seven layers in the ISO OSI model [11].",
                    choices: [
                        "Six layers.",
                        "Five layers.",
                        "Four layers.",
                        "Seven layers."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The ISO OSI model is characterized by its division of networking tasks into a hierarchy of seven layers. Each layer has a specific set of responsibilities and interacts with the layers directly above and below it [1]."
                ),
                Regret(
                    regretPrompt: "What is the general approach used to introduce the ISO OSI layers in the source?",
                    regret: "A top-down approach, starting with the application layer [12, 13].",
                    choices: [
                        "A random order of layers.",
                        "A top-down approach, starting with the application layer.",
                        "A bottom-up approach, starting with the physical layer.",
                        "A middle-out approach, starting with the network layer."
                    ],
                    correctAnswerIndex: 1,
                    backgroundExplanation: "The text explains the OSI model by beginning with the layer that is closest to the end-user (the application layer) and then moving down through the layers that deal with more technical details of data transmission [13]."
                ),
                Regret(
                    regretPrompt: "Ideally, how do layers in the OSI model interact with each other?",
                    regret: "Each layer provides services to the layer directly above it and uses the services provided by the layer directly below it [13].",
                    choices: [
                        "Layers are completely independent and do not rely on each other.",
                        "All layers communicate directly with a central control unit.",
                        "Each layer provides services to the layer directly above it and uses the services provided by the layer directly below it.",
                        "Layers only interact with non-adjacent layers."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "The layered architecture is based on the idea of modularity. Each layer performs its specific functions and offers those functions as services to the layer above it. In turn, it relies on the services provided by the layer beneath it to carry out its own tasks [13, 14]."
                ),
                Regret(
                    regretPrompt: "What is the primary function of the application layer (layer 7)?",
                    regret: "To represent the functionality that forms the reason why we want to use the network [14].",
                    choices: [
                        "To physically transmit data over a medium.",
                        "To determine the best path for data to travel.",
                        "To ensure reliable data transfer between two points.",
                        "To represent the functionality that forms the reason why we want to use the network."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The application layer is the topmost layer and is concerned with the end-user's interaction with the network. It includes applications like email, web browsing, and online games – the actual tasks users want to perform using the network [14, 15]."
                ),
                Regret(
                    regretPrompt: "Is the application software (like a web browser) the same as the application layer?",
                    regret: "No, application software may use one or more application layer protocols but also has non-networking functionalities [15, 16].",
                    choices: [
                        "Yes, they are interchangeable terms.",
                        "The application layer is a specific type of application software.",
                        "Application software is a subset of the application layer.",
                        "No, application software may use one or more application layer protocols but also has non-networking functionalities."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "A web browser is an application that allows you to interact with the internet. When you request a web page, the browser uses the HTTP (Hypertext Transfer Protocol), which is an application layer protocol. However, the browser itself has many features (like displaying local files or changing its appearance) that are not part of the networking application layer [15]."
                ),
                Regret(
                    regretPrompt: "What is the role of application layer protocols?",
                    regret: "To achieve some network application-oriented goal, such as retrieving a Web page or sending an email [17].",
                    choices: [
                        "To manage the physical connections between network devices.",
                        "To handle the routing of data packets across networks.",
                        "To ensure the reliable transport of data segments.",
                        "To achieve some network application-oriented goal, such as retrieving a Web page or sending an email."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "Application layer protocols are specifically designed to enable particular network applications to function. For example, HTTP is the protocol for web browsing, and SMTP is the protocol for sending emails. New applications often require the development of new application layer protocols tailored to their specific needs [17, 18]."
                ),
                Regret(
                    regretPrompt: "Give an example of a common application layer protocol for retrieving web pages.",
                    regret: "HTTP (Hypertext Transfer Protocol) [18].",
                    choices: [
                        "POP3 (Post Office Protocol version 3).",
                        "FTP (File Transfer Protocol).",
                        "HTTP (Hypertext Transfer Protocol).",
                        "SMTP (Simple Mail Transfer Protocol)."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "HTTP is the foundation of data communication on the World Wide Web. It defines how web browsers and web servers communicate to exchange information, allowing users to view and interact with web pages [18]."
                ),
                Regret(
                    regretPrompt: "What is the function of SMTP (Simple Mail Transfer Protocol)?",
                    regret: "To send email [18].",
                    choices: [
                        "To transfer files between computers.",
                        "To receive email from a server.",
                        "To send email.",
                        "To manage network connections."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "SMTP is the standard protocol used for sending email messages between mail servers. When you send an email, your email client typically uses SMTP to forward the message to your mail server, which then uses SMTP to send it to the recipient's mail server [18]."
                ),
                Regret(
                    regretPrompt: "What is the purpose of POP3 (Post Office Protocol version 3)?",
                    regret: "To retrieve email from a server [18].",
                    choices: [
                        "To format email messages.",
                        "To secure email communication.",
                        "To send email messages.",
                        "To retrieve email from a server."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "POP3 is an application layer protocol used by email clients to download email messages from a mail server to the user's local device. Once downloaded, the messages are often deleted from the server (though this can be configured) [18]."
                ),
                Regret(
                    regretPrompt: "What are some details that the application layer should ideally not be concerned with?",
                    regret: "The physical medium used to carry messages and the manner in which the message is routed [19-21].",
                    choices: [
                        "The specific application being used by the user.",
                        "The content of the messages being exchanged.",
                        "The language in which the messages are written.",
                        "The physical medium used to carry messages and the manner in which the message is routed."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The application layer should be able to function regardless of whether the data is being transmitted over copper cable, fiber optic, or a wireless connection. Similarly, it shouldn't matter to the application how the message travels across the network to reach its destination. These lower-level details are handled by the layers below [20, 21]."
                ),
                Regret(
                    regretPrompt: "What service does the application layer ideally want from the layers below it?",
                    regret: "A 'pipe' running from one application layer component to the other, often connecting client and server processes [21, 22].",
                    choices: [
                        "A detailed understanding of the underlying network topology.",
                        "A direct and exclusive connection to the physical network.",
                        "A 'pipe' running from one application layer component to the other, often connecting client and server processes.",
                        "A complex system for managing network hardware."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "The application layer wants a simple, abstract way to send and receive data with its peer at the other end. It shouldn't have to worry about the complexities of network transmission; it just wants to put its data into a 'pipe' and have it arrive correctly at the destination [22]."
                ),
                Regret(
                    regretPrompt: "What are two contentious issues that are considered after the 'pipe' abstraction but before lower layers?",
                    regret: "Data representation and whether message sequence should be part of the application layer [22, 23].",
                    choices: [
                        "User authentication and authorization.",
                        "Hardware compatibility and cost.",
                        "Network speed and security.",
                        "Data representation and whether message sequence should be part of the application layer."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "Before handing data down to the lower layers that handle the 'pipe', the OSI model considers issues like how data should be formatted so that different systems can understand it (data representation) and whether the application layer should be responsible for ensuring messages arrive in the correct order (message sequence) [23]."
                ),
                Regret(
                    regretPrompt: "What is the primary conceptual role of the presentation layer (layer 6)?",
                    regret: "To handle data representation and ensure that information is in a usable format for the application layer [23, 24].",
                    choices: [
                        "To handle the routing of data packets.",
                        "To establish and terminate network connections.",
                        "To provide reliable data transfer.",
                        "To handle data representation and ensure that information is in a usable format for the application layer."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The presentation layer is concerned with how data is presented to applications and users. This includes things like character encoding (e.g., ASCII, UTF-8), data compression, and encryption. It aims to solve problems arising from different systems representing data in different ways [23, 25]."
                ),
                Regret(
                    regretPrompt: "Give an example of a difference in data representation that the presentation layer could theoretically handle.",
                    regret: "Different character encoding schemes like ASCII and EBCDIC [25, 26].",
                    choices: [
                        "Different network cable types.",
                        "Different routing algorithms.",
                        "Different IP addressing schemes.",
                        "Different character encoding schemes like ASCII and EBCDIC."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "Computers use numerical codes to represent characters. For instance, the letter 'A' is represented by the number 65 in ASCII, but by 193 in EBCDIC. If two computers use different encoding schemes, they won't be able to understand each other's text directly. The presentation layer could, in theory, translate between these different formats [24, 25]."
                ),
                Regret(
                    regretPrompt: "Why is character encoding translation not commonly handled by a separate presentation layer in practice today?",
                    regret: "Many application layer protocols deal with character encoding directly [27, 28].",
                    choices: [
                        "Presentation layers are no longer used in modern networks.",
                        "Lower layers of the OSI model automatically handle this translation.",
                        "All computers now use the same character encoding scheme.",
                        "Many application layer protocols deal with character encoding directly."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "Modern protocols like HTTP allow the client and server to negotiate the character encoding to be used. For example, a browser can tell the server which encoding schemes it understands [28, 29]. This means the presentation layer doesn't need to perform this translation as a separate function in many cases."
                ),
                Regret(
                    regretPrompt: "Besides character encoding, what are some other examples of data format differences that a presentation layer could, in principle, address?",
                    regret: "Date and time formats, as well as cultural conventions like the start of the weekend [30, 31].",
                    choices: [
                        "Network bandwidth limitations.",
                        "The type of operating system used by the computers.",
                        "The number of routers between sender and receiver.",
                        "Date and time formats, as well as cultural conventions like the start of the weekend."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The way we represent dates (e.g., day/month/year vs. month/day/year) and our understanding of concepts like 'fall' or 'weekend' can vary geographically. A presentation layer could theoretically handle these differences to ensure clear communication across different regions [30-32]."
                ),
                Regret(
                    regretPrompt: "Where is the functionality of the presentation layer often found in modern networks?",
                    regret: "Included in the application layer or even in external utilities [33, 34].",
                    choices: [
                        "Integrated into the operating system's core networking functions.",
                        "As a distinct and separate layer in all network protocols.",
                        "Included in the application layer or even in external utilities.",
                        "Primarily within network hardware devices like routers."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "While the OSI model defines the presentation layer as a separate entity, in practice, many of its functions (like encoding and decoding data) are often handled by the applications themselves or by separate tools that are not strictly part of the protocol stack [33]."
                ),
                Regret(
                    regretPrompt: "What is the main purpose of the session layer (layer 5)?",
                    regret: "To establish, maintain, and terminate sessions between applications [34].",
                    choices: [
                        "To physically connect network devices.",
                        "To translate data formats between different systems.",
                        "To route data packets across networks.",
                        "To establish, maintain, and terminate sessions between applications."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The session layer is responsible for managing the connections (sessions) between applications that are communicating. This can involve setting up the connection, keeping it alive during the communication, and then properly ending it when the communication is finished [34]."
                ),
                Regret(
                    regretPrompt: "What is dialogue control, a function that the session layer may enforce?",
                    regret: "Determining which of the connected (application) nodes may send a message at any given moment, and which messages may be sent [34].",
                    choices: [
                        "Controlling the physical flow of data on the network cable.",
                        "Encrypting the data being transmitted during a session.",
                        "Managing user login and logout procedures.",
                        "Determining which of the connected (application) nodes may send a message at any given moment, and which messages may be sent."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "Dialogue control helps manage the flow of communication in a session. For example, in some protocols, only one party can send data at a time, while the other listens. The session layer can enforce these rules [34]."
                ),
                Regret(
                    regretPrompt: "Consider a travel agency booking system. What session layer functionality might be useful?",
                    regret: "Managing connections with multiple airlines, handling temporary unresponsiveness, and potentially using backup servers transparently to the application [35-39].",
                    choices: [
                        "Physically connecting the agency's computer to the airlines' systems.",
                        "Managing connections with multiple airlines, handling temporary unresponsiveness, and potentially using backup servers transparently to the application.",
                        "Encrypting passenger data for security.",
                        "Translating flight information into different languages."
                    ],
                    correctAnswerIndex: 1,
                    backgroundExplanation: "The session layer could handle the complexities of maintaining connections with various airline systems. If one system is busy, the session layer might retry or connect to a backup without the travel agent's application needing to manage these details directly [38, 39]."
                ),
                Regret(
                    regretPrompt: "What is a synchronisation point that the session layer might use in a transaction (like booking multiple connecting flights)?",
                    regret: "A marker indicating a point in the communication where the session layer can replay actions from in case of failure [40, 41].",
                    choices: [
                        "The moment when the user enters their credit card details.",
                        "A marker indicating a point in the communication where the session layer can replay actions from in case of failure.",
                        "A point in time when all connected systems must have the same data.",
                        "The beginning of a network connection."
                    ],
                    correctAnswerIndex: 1,
                    backgroundExplanation: "If a series of actions needs to happen together (like booking all flights in a connecting journey), the session layer can mark the start of this transaction. If a network failure occurs midway, the session layer can try to re-establish the connection and redo the steps from the last synchronisation point to ensure data consistency [40, 41]."
                ),
                Regret(
                    regretPrompt: "In many current protocols, where is the kind of fault tolerance (like automatic retries or using backup servers) often implemented?",
                    regret: "As part of the application layer protocol itself, rather than a separate session layer [41, 42].",
                    choices: [
                        "Primarily within the network layer.",
                        "Managed centrally by internet service providers.",
                        "As part of the application layer protocol itself, rather than a separate session layer.",
                        "As a core function of the physical network infrastructure."
                    ],
                    correctAnswerIndex: 2,
                    backgroundExplanation: "While the OSI model envisions the session layer handling fault tolerance, in practice, many applications (like email clients trying to resend failed emails) have this logic built directly into their protocols [42]."
                ),
                Regret(
                    regretPrompt: "How is the notion of a session layer often used in the context of modern application protocols like POP3?",
                    regret: "To refer to the sequence of events or the dialogue control within the application's communication (e.g., logon before retrieving messages) [42, 43].",
                    choices: [
                        "To denote the encryption methods used for secure communication.",
                        "To refer to the routing paths taken by the protocol's messages.",
                        "To describe the physical connection established by the protocol.",
                        "To refer to the sequence of events or the dialogue control within the application's communication (e.g., logon before retrieving messages)."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "In POP3, you need to log in with a username and password before you can retrieve your emails, and finally, you quit the session. This ordered sequence of commands and responses within the POP3 protocol is often what's meant by 'session' in this context [43]."
                ),
                Regret(
                    regretPrompt: "What is the main function provided by the transport layer (layer 4)?",
                    regret: "It enables process-to-process communication across the network, providing a 'pipe' between applications [44, 45].",
                    choices: [
                        "Determining the network topology.",
                        "Translating between different data encoding formats.",
                        "Defining the physical characteristics of the network medium.",
                        "It enables process-to-process communication across the network, providing a 'pipe' between applications."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The transport layer acts as a bridge between the application layer and the lower layers that handle the details of network transmission. It allows applications running on different computers to communicate with each other without needing to know about the underlying network infrastructure [45]."
                ),
                Regret(
                    regretPrompt: "What does the transport layer hide from the layers above it?",
                    regret: "Lower-level details such as the types of media used and how messages are routed [45].",
                    choices: [
                        "The content of the data being transmitted.",
                        "The specific application being used.",
                        "The need for encryption.",
                        "The types of media used and how messages are routed."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The application, presentation, and session layers don't need to worry about whether the data is traveling over Wi-Fi, Ethernet cable, or satellite, or the specific path it takes across the network. The transport layer handles these complexities [45]."
                ),
                Regret(
                    regretPrompt: "What is a reliable end-to-end connection that the transport layer can provide?",
                    regret: "A connection that includes mechanisms for retransmission of lost messages and congestion control, ensuring higher layers are aware of failures [46].",
                    choices: [
                        "A very fast network connection with minimal delay.",
                        "A connection that is physically secure from eavesdropping.",
                        "A connection that is physically robust against damage.",
                        "A connection that includes mechanisms for retransmission of lost messages and congestion control, ensuring higher layers are aware of failures."
                    ],
                    correctAnswerIndex: 3,
                    backgroundExplanation: "The transport layer provides a reliable connection by detecting lost packets and controlling data flow to prevent network congestion. This ensures that the data reaches its destination intact, or that higher layers are notified of transmission failures [46]."
                )
                
            ])
        }
    }
    
    private func saveRegrets() {
        do {
            let encoded = try JSONEncoder().encode(regrets)
            UserDefaults.standard.set(encoded, forKey: "SavedRegrets")
        } catch {
            print("Error saving regrets: \(error)")
        }
    }
    
    func cycleRegret() {
        currentRegretIndex = (currentRegretIndex + 1) % regrets.count
    }
    
    func updateRegret(_ updatedRegret: Regret) {
        if let index = regrets.firstIndex(where: { $0.id == updatedRegret.id }) {
            regrets[index] = updatedRegret
            saveRegrets()
        }
    }
    
    func addRegrets(_ newRegrets: [Regret]) {
        regrets.append(contentsOf: newRegrets)
        saveRegrets()
    }
    
    func addRegret(_ regret: Regret) {
        regrets.append(regret)
        saveRegrets()
    }
    
    func selectRegret(_ regret: Regret) {
        selectedRegret = regret
        saveRegrets()
    }
}


class DeckStore: ObservableObject {
    static let shared = DeckStore()
    
    @Published var decks: [Deck] {
        didSet {
            saveDecks()
        }
    }
    
    @Published var selectedDeck: Deck? {
        didSet {
            saveSelectedDeck()
        }
    }
    
    private func saveSelectedDeck() {
        if let deck = selectedDeck {
            UserDefaults.standard.set(deck.id.uuidString, forKey: "SelectedDeckID")
        }
    }
    
    func loadSelectedDeck() {
        if let deckID = UserDefaults.standard.string(forKey: "SelectedDeckID") {
            selectedDeck = decks.first { $0.id.uuidString == deckID }
        }
    }
    
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "SavedDecks"),
           let savedDecks = try? JSONDecoder().decode([Deck].self, from: data) {
            self.decks = savedDecks
        } else {
            self.decks = []
            addSampleData()
        }
        loadSelectedDeck()
    }
    func selectDeck(_ deck: Deck) {
        selectedDeck = deck
    }
     func saveDecks() {
        do {
            let encoded = try JSONEncoder().encode(decks)
            UserDefaults.standard.set(encoded, forKey: "SavedDecks")
        } catch {
            print("Error saving decks: \(error)")
        }
    }
    
    func addDeck(_ deck: Deck) {
        decks.insert(deck, at: 0)    }
    
    func updateDeck(_ updatedDeck: Deck) {
        if let index = decks.firstIndex(where: { $0.id == updatedDeck.id }) {
            decks[index] = updatedDeck
        }
    }
    
    func deleteDeck(at offsets: IndexSet) {
        decks.remove(atOffsets: offsets)
    }
    
    private func addSampleData() {
        let sampleDeck = Deck(
            name: "Networking Fundamentals",
            cards: [
                Regret(regretPrompt: "This is the regret propmt buddy boy of the new deck?",
                       regret: "This sould be the naser bdfufhsuf",
                       choices: ["Option 1", "Option 2", "Option 3", "Option 4"],
                       correctAnswerIndex: 0,
                       backgroundExplanation: "Studies show people who prioritize family time report higher life satisfaction and lower end-of-life regrets."
                      )
            ]
        )
        decks.append(sampleDeck)
    }
}
