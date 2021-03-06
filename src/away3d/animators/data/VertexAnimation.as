package away3d.animators.data
{
	import away3d.arcane;
	import away3d.materials.passes.MaterialPassBase;
	import away3d.materials.utils.AGAL;

	import flash.display3D.Context3D;

	use namespace arcane;

	/**
	 * VertexAnimation defines an animation type that blends different poses (geometries) together to create a final pose.
	 */
	public class VertexAnimation extends AnimationBase
	{
		arcane var _streamIndex : uint;
		arcane var _useNormals : Boolean;
		arcane var _useTangents : Boolean;
		arcane var _numPoses : uint;
		private var _blendMode : String;

		/**
		 * Creates a new VertexAnimation object
		 * @param numPoses The amount of poses to be blended together.
		 * @param blendMode The type of blending to be performed by the animation. The following values are supported:
		 * <ul>
		 * <li>VertexAnimationMode.ADDITIVE: The pose is generated from a base mesh and a number of additive "difference" poses.</li>
		 * <li>VertexAnimationMode.ABSOLUTE: The pose is generated by a weighted average of a number of poses.</li>
		 * </ul>
		 */
		public function VertexAnimation(numPoses : uint, blendMode : String)
		{
			super();
			_numPoses = numPoses;
			_blendMode = blendMode;
		}

		/**
		 * The type of blending to be performed by the animation.
		 */
		public function get blendMode() : String
		{
			return _blendMode;
		}

		/**
		 * @inheritDoc
		 */
		override arcane function createAnimationState() : AnimationStateBase
		{
			return new VertexAnimationState(this);
		}

		/**
		 * @inheritDoc
		 */
		override arcane function deactivate(context : Context3D, pass : MaterialPassBase) : void
		{
			context.setVertexBufferAt(_streamIndex, null);
			if (_useNormals)
				context.setVertexBufferAt(_streamIndex + 1, null);
			if (_useTangents)
				context.setVertexBufferAt(_streamIndex + 2, null);
		}

		/**
		 * @inheritDoc
		 */
		override arcane function getAGALVertexCode(pass : MaterialPassBase) : String
		{
			if (_blendMode == VertexAnimationMode.ABSOLUTE)
				return getAbsoluteAGALCode(pass);
			else
				return getAdditiveAGALCode(pass);
		}

		/**
		 * Generates the vertex AGAL code for absolute blending.
		 */
		private function getAbsoluteAGALCode(pass : MaterialPassBase) : String
		{
			var attribs : Array = pass.getAnimationSourceRegisters();
			var targets : Array = pass.getAnimationTargetRegisters();
			var code : String = "";
			var temp1 : String = findTempReg(targets);
			var temp2 : String = findTempReg(targets, temp1);
			var regs : Array = ["x", "y", "z", "w"];
			var len : uint = attribs.length;
			_useNormals = len > 1;
			_useTangents = len > 2;
			if (len > 2) len = 2;
			_streamIndex = pass.numUsedStreams;

			var k : uint;
			for (var i : uint = 0; i < len; ++i) {
				for (var j : uint = 0; j < _numPoses; ++j) {
					if (j == 0) {
						code += AGAL.mul(temp1, attribs[i], "vc" + pass.numUsedVertexConstants + "." + regs[j]);
					}
					else {
						code += AGAL.mul(temp2, "va" + (_streamIndex + k), "vc" + pass.numUsedVertexConstants + "." + regs[j]);
						if (j < _numPoses - 1) code += AGAL.add(temp1, temp1, temp2);
						else code += AGAL.add(targets[i], temp1, temp2);
						++k;
					}
				}
			}

			if (_useTangents) {
				code += AGAL.dp3(temp1 + ".x", attribs[uint(2)], targets[uint(1)]);
				code += AGAL.mul(temp1, targets[uint(1)], temp1 + ".x");
				code += AGAL.sub(targets[uint(2)], attribs[uint(2)], temp1);
			}
			return code;
		}

		private function getAdditiveAGALCode(pass : MaterialPassBase) : String
		{
			var attribs : Array = pass.getAnimationSourceRegisters();
			var targets : Array = pass.getAnimationTargetRegisters();
			var code : String = "";
			var len : uint = attribs.length;
			var regs : Array = ["x", "y", "z", "w"];
			var temp1 : String = findTempReg(targets);
			var k : uint;

			_useNormals = len > 1;
			_useTangents = len > 2;

			if (len > 2) len = 2;

			code += AGAL.mov(targets[0], attribs[0]);
			if (_useNormals) code += AGAL.mov(targets[1], attribs[1]);

			for (var i : uint = 0; i < len; ++i) {
				for (var j : uint = 0; j < _numPoses; ++j) {
					code += AGAL.mul(temp1, "va" + (_streamIndex + k), "vc" + pass.numUsedVertexConstants + "." + regs[j]);
					code += AGAL.add(targets[i], targets[i], temp1);
					k++;
				}
			}

			if (_useTangents) {
				code += AGAL.dp3(temp1 + ".x", attribs[uint(2)], targets[uint(1)]);
				code += AGAL.mul(temp1, targets[uint(1)], temp1 + ".x");
				code += AGAL.sub(targets[uint(2)], attribs[uint(2)], temp1);
			}

			return code;
		}

		/**
		 * Retrieves a temporary register that's still free.
		 * @param exclude An array of non-free temporary registers
		 * @param excludeAnother An additional register that's not free
		 * @return A temporary register that can be used
		 */
		private function findTempReg(exclude : Array, excludeAnother : String = null) : String
		{
			var i : uint;
			var reg : String;

			while (true) {
				reg = "vt" + i;
				if (exclude.indexOf(reg) == -1 && excludeAnother != reg) return reg;
				++i;
			}

			// can't be reached
			return null;
		}
	}
}