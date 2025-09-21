import torch


def check_environment() -> None:
   """Check the environment for potential issues"""
   print('Environment Check:')
   print(f'PyTorch CUDA available: {torch.cuda.is_available()}')


   if torch.cuda.is_available():
       print(f'PyTorch CUDA version: {torch.version.cuda}')
       print(f'Detected CUDA devices: {torch.cuda.device_count()}')


       # Try a simple CUDA operation
       try:
           x = torch.randn(2, 2).cuda()
           y = torch.randn(2, 2).cuda()
           z = torch.mm(x, y)
           print('Basic CUDA operations work')
       except Exception as e:
           print(f'Basic CUDA operations failed: {e}')


   # Check if torchvision ops work
   try:
       from torchvision.ops import nms


       boxes = torch.tensor([[0, 0, 1, 1], [0, 0, 1, 1]], dtype=torch.float32)
       scores = torch.tensor([0.9, 0.8], dtype=torch.float32)


       if torch.cuda.is_available():
           boxes = boxes.cuda()
           scores = scores.cuda()


       keep = nms(boxes, scores, 0.5)
       print('torchvision.ops.nms works on current device')	
   except Exception as e:
       print(f'torchvision.ops.nms failed: {e}')
if __name__ == '__main__':
   check_environment()