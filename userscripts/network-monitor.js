// Network Monitor for Reddit Mute API Discovery
// Run this in the browser console before using Reddit's native mute feature

(function() {
    'use strict';

    console.log('🔍 Reddit Mute API Monitor Started');
    console.log('📋 Instructions:');
    console.log('1. Navigate to a subreddit (e.g., /r/ExplainTheJoke)');
    console.log('2. Click the "Mute" option in the subreddit menu');
    console.log('3. Watch the console for captured API calls');
    console.log('');

    // Store original fetch function
    const originalFetch = window.fetch;

    // Override fetch to monitor API calls
    window.fetch = function(...args) {
        const [url, options] = args;

        // Log all POST requests that might be mute-related
        if (options && options.method === 'POST') {
            console.log('🌐 POST Request Detected:');
            console.log('URL:', url);
            console.log('Headers:', options.headers);
            console.log('Body:', options.body);
            console.log('---');
        }

        // Call original fetch and log response
        return originalFetch.apply(this, args).then(response => {
            if (options && options.method === 'POST') {
                console.log('📥 Response for:', url);
                console.log('Status:', response.status);
                console.log('Headers:', Object.fromEntries(response.headers.entries()));

                // Clone response to read body without consuming it
                const clonedResponse = response.clone();
                clonedResponse.text().then(text => {
                    console.log('Response Body:', text.substring(0, 500) + (text.length > 500 ? '...' : ''));
                    console.log('---');
                });
            }
            return response;
        });
    };

    // Also monitor XMLHttpRequest
    const originalXHROpen = XMLHttpRequest.prototype.open;
    const originalXHRSend = XMLHttpRequest.prototype.send;

    XMLHttpRequest.prototype.open = function(method, url, ...args) {
        this._method = method;
        this._url = url;
        return originalXHROpen.apply(this, [method, url, ...args]);
    };

    XMLHttpRequest.prototype.send = function(data) {
        if (this._method === 'POST') {
            console.log('🌐 XHR POST Request:');
            console.log('URL:', this._url);
            console.log('Data:', data);

            this.addEventListener('load', () => {
                console.log('📥 XHR Response for:', this._url);
                console.log('Status:', this.status);
                console.log('Response:', this.responseText.substring(0, 500) + (this.responseText.length > 500 ? '...' : ''));
                console.log('---');
            });
        }
        return originalXHRSend.apply(this, [data]);
    };

    console.log('✅ Network monitoring active. Now use Reddit\'s native mute feature!');

    // Provide a way to stop monitoring
    window.stopMuteMonitoring = function() {
        window.fetch = originalFetch;
        XMLHttpRequest.prototype.open = originalXHROpen;
        XMLHttpRequest.prototype.send = originalXHRSend;
        console.log('🛑 Network monitoring stopped');
    };

    console.log('💡 To stop monitoring, run: stopMuteMonitoring()');
})();
