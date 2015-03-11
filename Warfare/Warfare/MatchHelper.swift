//
//  MatchHelper.swift
//  Warfare
//
//  Created by Justin Domingue on 2015-02-16.
//  Copyright (c) 2015 Justin Domingue. All rights reserved.
//

import Foundation
import GameKit

private var sharedHelper: MatchHelper?

class MatchHelper: NSObject, GKTurnBasedMatchmakerViewControllerDelegate, GKLocalPlayerListener {
    var gameCenterAvailable: Bool {
        // Check for presence of GKLocalPlayer API
        let gClass: AnyClass? = NSClassFromString("GKLocalPlayer")
        
        // NOTE: No need to check if device is iOS 4.1 or higher
        return gClass != nil
    }
    var userAuthenticated = false
    
    var vc: UIViewController?
    var myMatch: GKTurnBasedMatch?
    
    override init() {
        super.init()
        
        if self.gameCenterAvailable {
            let nc = NSNotificationCenter.defaultCenter()
            nc.addObserver(self, selector: Selector("authenticationChanged"), name:GKPlayerAuthenticationDidChangeNotificationName, object: nil)
        }
        
    }
    
    class func sharedInstance() -> MatchHelper {
        if sharedHelper == nil {
            sharedHelper = MatchHelper()
        }
        
        return sharedHelper!
    }
    
    func currentParticipantIndex() -> Int {
        let participants: [GKTurnBasedParticipant] = self.myMatch?.participants as [GKTurnBasedParticipant]
        
        for (index, p) in enumerate(participants) {
            if p === self.myMatch?.currentParticipant {
                return index
            }
        }
        
        // fallback
        return 0
    }
    
    // MARK: - Authentication
    
    func authenticateLocalUser() {
        if !gameCenterAvailable { return }
        
        if !GKLocalPlayer.localPlayer().authenticated {
            var localPlayer = GKLocalPlayer.localPlayer()
            localPlayer.authenticateHandler = {(viewController : UIViewController!, error : NSError!) -> Void in
                if ((viewController) != nil) {
                    self.vc?.presentViewController(viewController, animated: true, completion: nil)
                }else{
                    self.userAuthenticated = true
                }
            }
        }
    }
    
    func authenticationChanged() {
        if GKLocalPlayer.localPlayer().authenticated && !self.userAuthenticated {
            self.userAuthenticated = true
            GKLocalPlayer.localPlayer().unregisterAllListeners()
            GKLocalPlayer.localPlayer().registerListener(self)
            println("Registered GKLocalPlayer listener")
        } else if !GKLocalPlayer.localPlayer().authenticated && self.userAuthenticated {
            self.userAuthenticated = false
        }
    }
    
    // MARK: - GKMatch
    
    func joinMatch() {
        if self.userAuthenticated {
            // Create match request
            let request = GKMatchRequest()
            request.minPlayers = 3
            request.maxPlayers = 3
            request.defaultNumberOfPlayers = 3
    
            
            let mmvc = GKTurnBasedMatchmakerViewController(matchRequest: request)
            mmvc.turnBasedMatchmakerDelegate = self
            
            self.vc?.presentViewController(mmvc, animated: true, completion: nil)
        }
    }
    
    func loadMatchData() {
        self.myMatch?.loadMatchDataWithCompletionHandler({ (matchData: NSData!, error: NSError!) -> Void in
            // If match data has length of 0, the game is *new*, else, decode it
            if matchData.length > 0 {
                GameEngine.Instance.decode(matchData)
            } else {
                GameEngine.Instance.newGame()
                self.updateMatchData()
            }
        })
    }
    
    // If the player takes an action that is irrevocable 
    // (but control is not yet passed to another player), 
    // encode the updated match data and send it to Game Center
    //
    func updateMatchData() {
        let updatedMatchData = GameEngine.Instance.encodeMatchData()
        
        self.myMatch?.saveCurrentTurnWithMatchData(updatedMatchData, completionHandler: {(error: NSError!) -> Void in
            if ((error) != nil) {
                println(error)
            }
        })
    }
    
    //  the current player takes an action that either ends 
    // the match or requires another participant to act
    //
    func advanceTurn() {
        if let match = self.myMatch {
            
            let updatedMatchData = GameEngine.Instance.encodeMatchData()
            self.myMatch?.message = GameEngine.Instance.encodeTurnMessage()
            
            let current = self.currentParticipantIndex()
    
            let nextParticipants = NSMutableArray(capacity: 3)
            nextParticipants[0] = (self.myMatch?.participants[(current+1)%3])!
            nextParticipants[1] = (self.myMatch?.participants[(current+2)%3])!
            nextParticipants[2] = (self.myMatch?.participants[current])! // should be current participant
            
            self.myMatch?.endTurnWithNextParticipants(nextParticipants, turnTimeout: GKTurnTimeoutDefault, matchData: updatedMatchData, completionHandler: {(error: NSError!) -> Void in
                if ((error) != nil) {
                    println(error)
                }
            })

        }
    }
    
    func endMatch() {
        // Set match outcome for each participant
        // TODO
        for p in self.myMatch?.participants as [GKTurnBasedParticipant] {
            if p.matchOutcome == .None {
                p.matchOutcome == .Tied
            }
        }
        
        let finalMatchData = GameEngine.Instance.encodeMatchData()
        self.myMatch?.endMatchInTurnWithMatchData(finalMatchData, completionHandler: {(error: NSError!) -> Void in})
    }
    
    // Mark: - GKTurnBasedMatchViewControllerDelegate
    
    func turnBasedMatchmakerViewControllerWasCancelled(controller: GKTurnBasedMatchmakerViewController!) {
        self.vc?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func turnBasedMatchmakerViewController(controller: GKTurnBasedMatchmakerViewController!, didFindMatch match: GKTurnBasedMatch!) {
        self.myMatch = match
        self.loadMatchData()
        self.vc?.dismissViewControllerAnimated(true, completion: ({() in
            // Create GameViewController and move to it
            if let mmvc = self.vc as? MainMenuViewController {
                mmvc.segueToGameViewController()
            }}))
    }
    
    func turnBasedMatchmakerViewController(controller: GKTurnBasedMatchmakerViewController!, playerQuitForMatch match: GKTurnBasedMatch!) {
        
        let participants = match.participants!
        
        // Make next participant array
        var nextParticipants = [GKTurnBasedParticipant]()
        for p in participants {
             if p.playerID! != nil && p.playerID! == GKLocalPlayer.localPlayer().playerID {
                nextParticipants.append(p as GKTurnBasedParticipant)
             } else {
                nextParticipants.insert(p as GKTurnBasedParticipant, atIndex: 0)
            }
        }
        
        // Send quit
        // TODO matchData mught not be the most up to date
        match.participantQuitInTurnWithOutcome(.Quit, nextParticipants: nextParticipants, turnTimeout: GKTurnTimeoutDefault, matchData: match.matchData, completionHandler: nil)
    }
    
    func turnBasedMatchmakerViewController(controller: GKTurnBasedMatchmakerViewController!, didFailWithError: NSError!) {
        self.vc?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // Mark: - GKTurnBasedEventListener
    
    // Mark: Handling Exchanges
       func player(player: GKPlayer!, receivedExchangeCancellation exchange: GKTurnBasedExchange!, forMatch match: GKTurnBasedMatch!) {
        // Do nothing
    }
    
    func player(player: GKPlayer!, receivedExchangeReplies replies: GKTurnBasedExchange!, forCompletedExchange exchange: GKTurnBasedExchange!,forMatch match: GKTurnBasedMatch!) {
        // Do nothing
    }
    
    func player(player: GKPlayer!,
        receivedExchangeRequest exchange: GKTurnBasedExchange!,
        forMatch match: GKTurnBasedMatch!) {
        // Do nothing
    }
    
    // Mark: Handling Match Related Events
    
    func player(player: GKPlayer!,
        didRequestMatchWithOtherPlayers playersToInvite: [AnyObject]!) {
            
    }
    
    func player(player: GKPlayer!,
        matchEnded match: GKTurnBasedMatch!) {
            
    }
    
    func player(player: GKPlayer!,
        receivedTurnEventForMatch match: GKTurnBasedMatch!,
        didBecomeActive: Bool) {
            if didBecomeActive {
                self.myMatch = match
                self.loadMatchData()
            }
    }
}