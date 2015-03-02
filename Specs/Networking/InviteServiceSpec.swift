//
//  InviteServiceSpec.swift
//  Ello
//
//  Created by Sean on 2/27/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Quick
import Moya
import Nimble

class InviteServiceSpec: QuickSpec {
    override func spec() {
        describe("-invite:success:failure:") {

            var subject = InviteService()

            // TODO: handle no content 204 responses when mapping
            // they are currently misidentified as a failed response due
            // to no content being present in the json
            xit("succeeds") {
                ElloProvider.sharedProvider = MoyaProvider(endpointsClosure: ElloProvider.endpointsClosure, stubResponses: true)
                var loadedSuccessfully = false
                subject.invite(["1", "2", "3"], success: {
                    loadedSuccessfully = true
                }, failure: nil)

                expect(loadedSuccessfully) == true
            }

            it("fails") {
                ElloProvider.sharedProvider = MoyaProvider(endpointsClosure: ElloProvider.errorEndpointsClosure, stubResponses: true)
                var loadedSuccessfully = true
                subject.invite(["1", "2", "3"], success: {
                    loadedSuccessfully = true
                }, failure: { (error, statusCode) -> () in
                    loadedSuccessfully = false
                })

                expect(loadedSuccessfully) == false
            }
        }

        describe("-find:success:failure:") {

            var subject = InviteService()

            it("succeeds") {
                ElloProvider.sharedProvider = MoyaProvider(endpointsClosure: ElloProvider.endpointsClosure, stubResponses: true)
                var loadedSuccessfully = false
                var expectedUsers = [User]()
                subject.find([["1":"blah"], ["2":"blah"]], success: {
                    users in
                    expectedUsers = users
                }, failure: nil)

                expect(countElements(expectedUsers)) == 2
            }

            it("fails") {
                ElloProvider.sharedProvider = MoyaProvider(endpointsClosure: ElloProvider.errorEndpointsClosure, stubResponses: true)
                var loadedSuccessfully = true

                subject.find([["1":"blah"], ["2":"blah"]], success: {
                    users in
                    loadedSuccessfully = true
                }, failure: { (error, statusCode) -> () in
                    loadedSuccessfully = false
                })

                expect(loadedSuccessfully) == false
            }
        }
    }
}
