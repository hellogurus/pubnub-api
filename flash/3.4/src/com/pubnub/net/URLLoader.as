package com.pubnub.net {
	import com.adobe.net.*;
	import com.hurlant.crypto.tls.TLSSocket;
	import com.pubnub.log.Log;
	import flash.errors.IOError;
	import flash.events.*;
	import flash.net.Socket;
	import flash.utils.*;
	
	/**
	 * ...
	 * @author firsoff maxim, firsoffmaxim@gmail.com, icq : 235859730
	 */
	[Event(name="URLLoaderEvent.complete", type="com.pubnub.net.URLLoaderEvent")]
	[Event(name="URLLoaderEvent.error", type="com.pubnub.net.URLLoaderEvent")]
	public class URLLoader extends EventDispatcher {
		
		public static const HTTP_PORT:uint = 80;   
		public static const HTTPS_PORT:uint = 443; 
		public static const HTTP_VERSION:String = "1.1";
		
		public static const END_SYMBOL_CHUNKED:String = '0\r\n';
		public static const END_SYMBOL:String = '\r\n';
		static private const pattern:RegExp = new RegExp("(https):\/\/");
		
		protected var socket:*;
		protected var secureSocket:TLSSocket;
		protected var normalSocket:Socket;
		protected var uri:URI;
		protected var request:URLRequest;
		protected var _response:URLResponse;
		protected var answer:ByteArray = new ByteArray();
		protected var temp:ByteArray = new ByteArray();
		
		
		protected var _destroyed:Boolean;
		
		public function URLLoader() {
			super(null);
			init();
		}
		
		public function load(request:URLRequest):void {
			this.request = request;
			uri = new URI(request.url);
			//trace(request.url);
			socket = getSocket(request.url);
			destroyResponce();
			sendRequest(request);
			Log.logURL(unescape(request.url), Log.DEBUG);
		}
		
		private function getSocket(url:String):*{
			return pattern.test(url) ? secureSocket : normalSocket;
		}
		
		private function getPort(url:String):*{
			return pattern.test(url) ? HTTPS_PORT : HTTP_PORT;
		}
		
		public function connect(request:URLRequest):void {
			if (!request) return;
			var url:String = request.url;
			var uri:URI = new URI(url);
			var host:String = uri.authority;
			//trace(host);
			var port:int = getPort(url);
			socket = getSocket(url);
			//trace('connect : ' + host, port, socket);
			socket.connect(host, port);
		}
		
		public function close():void {
			//trace('*CLOSE* ' + socket);
			try {
				if(normalSocket.connected) normalSocket.close();
			}catch (err:IOError){
                Log.log("Close: " + err, Log.WARNING);
			}
			
			try {
				if (socket == secureSocket && secureSocket.connected) {
					secureSocket.close();
				}
			}catch (err:IOError){
                Log.log("Close: " + err, Log.WARNING);
			}
			destroyResponce();
			request = null;
		}
		
		protected function init():void {
			normalSocket = new Socket();
			normalSocket.addEventListener(Event.CONNECT, 						onConnect);       
			normalSocket.addEventListener(Event.CLOSE, 							onClose);
			normalSocket.addEventListener(IOErrorEvent.IO_ERROR, 				onIOError);
			normalSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, 	onSecurityError);
			normalSocket.addEventListener(ProgressEvent.SOCKET_DATA, 			onSocketData); 
			
			secureSocket = new TLSSocket();
			secureSocket.addEventListener(Event.CONNECT, 						onConnect);       
			secureSocket.addEventListener(Event.CLOSE, 							onClose);
			secureSocket.addEventListener(IOErrorEvent.IO_ERROR, 				onIOError);
			secureSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, 	onSecurityError);
			secureSocket.addEventListener(ProgressEvent.SOCKET_DATA, 			onSocketData);
			
			socket = normalSocket;
		}
		
		protected function onSocketData(e:ProgressEvent):void {
			//trace('------onSocketData------' + socket.bytesAvailable);
			temp.clear();
			while (socketHasData()) {        
				try {           
					// Load data from socket
					socket.readBytes(temp);
					temp.readBytes(answer, answer.bytesAvailable);
				} catch (e:Error) {
                    Log.log("onSocketData: " + e, Log.WARNING);
					break;
				}                           
			}
			
			temp.position = 0;
			var tempStr:String = temp.readUTFBytes(temp.bytesAvailable);
			var endSymbol:String = getEndSymbol(tempStr);
			//trace('tempStr: ' + tempStr);
			if (tempStr.indexOf(endSymbol) != -1) {
				onResponce(answer)
				answer.clear();	
			}
		}
		
		protected function getEndSymbol(tcpStr:String):String {
			var headers:Array = URLResponse.getHeaders(tcpStr);
			if (URLResponse.isChunked(headers)) {
				return END_SYMBOL_CHUNKED;
			}else {
				return END_SYMBOL;
			}
		}
		
		protected function onResponce(bytes:ByteArray):void {
			try {
				if (request) {
					_response = new URLResponse(bytes, request);
				}
				//trace('onResponce : ' + _response.body);
				dispatchEvent(new URLLoaderEvent(URLLoaderEvent.COMPLETE, _response));
			}catch (err:Error){
				dispatchEvent(new URLLoaderEvent(URLLoaderEvent.ERROR, _response));
			}
		}
		
		protected function socketHasData():Boolean {
			return (socket && socket.connected && socket.bytesAvailable);
		}
		
		protected function onSecurityError(e:SecurityErrorEvent):void {
			// abstract
			dispatchEvent(new URLLoaderEvent(URLLoaderEvent.ERROR, request));
		}
		
		protected function onIOError(e:IOErrorEvent):void {
			// abstract
			dispatchEvent(new URLLoaderEvent(URLLoaderEvent.ERROR, request));
		}
		
		protected function onClose(e:Event):void {
			//trace(socket, ' onClose');
			dispatchEvent(e);
		}
		
		protected function onConnect(e:Event):void {
			//trace(this, ' onConnect', socket);
			dispatchEvent(e);
		}
		
		public function get ready():Boolean { return socket && socket.connected ; }
		
		public function get connected():Boolean { return socket && socket.connected ; }
		
		private function destroyResponce():void {
			if (_response) {
				_response.destroy();
				_response = null;
			}
		}
		
		public function destroy():void {
			if (_destroyed) return;
			_destroyed = true;
			close()
			normalSocket.removeEventListener(Event.CONNECT, 						onConnect);       
			normalSocket.removeEventListener(Event.CLOSE, 							onClose);
			normalSocket.removeEventListener(IOErrorEvent.IO_ERROR, 				onIOError);
			normalSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, 	onSecurityError);
			normalSocket.removeEventListener(ProgressEvent.SOCKET_DATA, 			onSocketData); 
			
			
			secureSocket.removeEventListener(Event.CONNECT, 						onConnect);       
			secureSocket.removeEventListener(Event.CLOSE, 							onClose);
			secureSocket.removeEventListener(IOErrorEvent.IO_ERROR, 				onIOError);
			secureSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, 	onSecurityError);
			secureSocket.removeEventListener(ProgressEvent.SOCKET_DATA, 			onSocketData);
			socket = null;
			temp.clear();
			answer.clear();
			temp = answer = null;
			request = null;
		}
		
		/**
		 * Send request.
		 * @param request Request to write
		 */
		protected function sendRequest(request:URLRequest):void {
			if (ready) {
				doSendRequest(request);
			}else {
				connect(request);
			}
		}
		
		protected function doSendRequest(request:URLRequest):void {
			//trace('doSendRequest');
			var requestBytes:ByteArray = request.toByteArray();
			requestBytes.position = 0;
			// Debug
			//var hStr:String = "Header:\n" + requestBytes.readUTFBytes(requestBytes.length);
			//trace('socket.connected : ' + socket.connected);
			socket.writeBytes(requestBytes);      
			socket.flush();
		}
		
		
		public function get destroyed():Boolean {
			return _destroyed;
		}
		
		public function get response():URLResponse {
			return _response;
		}
	}
}